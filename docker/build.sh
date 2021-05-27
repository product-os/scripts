#!/usr/bin/env bash

# shellcheck disable=SC1091
source /docker-lib.sh
start_docker

docker --version

echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "${HERE}/image-cache.sh"

CONCOURSE_WORKDIR=$(pwd)
DOCKER_IMAGE_CACHE="${CONCOURSE_WORKDIR}/image-cache"
pushd "${ARGV_DIRECTORY}"

tmptoken=$(mktemp)
echo "${NPM_TOKEN}" > "${tmptoken}"

sha=$(cat < .git/.version | jq -r '.sha')
branch=$(cat < .git/.version | jq -r '.head_branch')
branch=${branch//[^a-zA-Z0-9_-]/-}
owner=$(cat < .git/.version | jq -r '.base_org')
repo=$(cat < .git/.version | jq -r '.base_repo')

# (TBC) remove once everything is migrated to balena-secrets/git-secret workflow, also:
# git@github.com:product-os/ci-images.git
# git@github.com:product-os/scripts.git
chamber export \
  --format dotenv "concourse/test-runtime-secrets/repos/${owner}/${repo}" \
  --output-file runtime-secrets

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

if [ -s runtime-secrets ]; then
  while IFS= read -r -d $'\n'
  do
    export "${REPLY?}"
  done < runtime-secrets
fi

rm -rf runtime-secrets

# https://git-secret.io/
if [[ -n ${GPG_PRIVATE_KEY} ]] && [[ -n ${GPG_PASSPHRASE} ]] \
  && which gpg2 && git secret --version; then
    tmpkey="$(mktemp)" \
      && echo "${GPG_PRIVATE_KEY}" | base64 -d > "${tmpkey}" \
      && GPG_TTY="$(tty)" \
      && export GPG_TTY \
      && echo "${GPG_PASSPHRASE}" | gpg2 \
      --pinentry-mode "${SECRETS_PINENTRY}" \
      --passphrase-fd 0 \
      --import "${tmpkey}" \
      && rm -f "${tmpkey}" \
      && gpg2 --list-keys \
      && gpg2 --list-secret-keys \
      && git secret reveal -fp "${GPG_PASSPHRASE}" \
      && git secret list \
      && git secret whoknows
fi

# register qemu binfmt for automatic emulated arm builds
# The `--reset` flag is intentionally not used, to avoid a race condition with
# any ongoing builds on the VM (that could result in `exec format error`).
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 -p yes

function image_variant() {
  local docker_image
  docker_image=$1
  local docker_tag
  docker_tag=${2:-default}

  if [[ "${docker_tag}" == 'default' ]]; then
    echo "${docker_image}"
    return
  fi

  local image_variant
  image_variant="$(echo "${docker_image}" | awk -F':' '{print $2}')"
  local docker_image
  docker_image="$(echo "${docker_image}" | awk -F':' '{print $1}')"

  if [[ "${image_variant}" == '' ]]; then
    echo "${docker_image}:${docker_tag}"
  else
    echo "${docker_image}:${image_variant}-${docker_tag}"
  fi
}

function is_buildx() {
    [[ ${DOCKER_BUILDKIT} -eq 1 ]] \
      && [[ "${DOCKER_CLI_EXPERIMENTAL}" == 'enabled' ]] \
      && docker buildx version
}

function build_with_opts() {
    local dockerfile=$1; shift
    local build_stages
    build_stages="$(grep -Ei '^FROM\s+.*\s+AS\s+.*$' "${dockerfile}" | tr '[:upper:]' '[:lower:]' | awk -F' as ' '{print $2}')"

    # multistage build handling
    for stage in ${build_stages}; do
        if is_buildx; then
            docker buildx build --target "${stage}" "$@"
        else
            docker build --target "${stage}" "$@"
        fi
    done

    # single-stage build handling and runtime stage
    if is_buildx; then
        docker buildx build "$@"
    else
        docker build "$@"
    fi
}

function build() {
  path=$1; shift
  DOCKERFILE=$1; shift
  DOCKER_IMAGE=$1; shift
  publish=$1; shift
  args=$1; shift
  secrets=$1; shift
  sha_image=$(image_variant "${DOCKER_IMAGE}" "${sha}")
  branch_image=$(image_variant "${DOCKER_IMAGE}" "build-${branch}")
  master_image=$(image_variant "${DOCKER_IMAGE}" master)
  latest_image=$(image_variant "${DOCKER_IMAGE}" latest)

  (
    cd "${path}"

    if [ "${publish}" != "false" ]; then
      docker pull "${sha_image}" || true
      docker pull "${branch_image}" || true
      docker pull "${master_image}" || true
    fi

    # shellcheck disable=SC2086
    build_with_opts \
      "${DOCKERFILE}" \
      --progress=plain \
      --cache-from "${sha_image}" \
      --cache-from "${branch_image}" \
      --cache-from "${master_image}" \
      ${args} \
      --build-arg RESINCI_REPO_COMMIT="${sha}" \
      --build-arg CI=true \
      --build-arg NPM_TOKEN="${NPM_TOKEN}" \
      ${secrets} \
      --secret id=npmtoken,src="${tmptoken}" \
      -t "${DOCKER_IMAGE}" \
      -f "${DOCKERFILE}" .

    docker tag $(image_variant ${DOCKER_IMAGE}) ${latest_image} || true

    # Scan the image with trivy and output to stdout
    trivy -f json -o trivy_output.json --no-progress --exit-code 0 --severity HIGH --ignore-unfixed ${latest_image}
    curl --location --request POST 'https://cln596sf9k.execute-api.us-east-1.amazonaws.com/default/trivy-scan-output' \
    --header 'auth: '${TRIVY_SCAN_TOKEN} \
    --header 'imagename: '${latest_image} \
    --header 'Content-Type: application/json' \
    --data @trivy_output.json
    rm trivy_output.json

    export_image "${DOCKER_IMAGE}" "${DOCKER_IMAGE_CACHE}"
  )
}

# Read the details of what we should build from .resinci.yml
builds=$("${HERE}/../shared/resinci-read.sh" \
  -b "$(pwd)" \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  build_pids=()
  for build in ${builds}; do
    echo "${build}"
    repo=$(echo "${build}" | jq -r '.docker_repo')
    dockerfile=$(echo "${build}" | jq -r '.dockerfile' || echo Dockerfile)
    path=$(echo "${build}" | jq -r '.path' || echo .)
    publish=$(echo "${build}" | jq -r '.publish' || echo true)
    args=$(echo "${build}" | jq -r '.args // [] | map("--build-arg " + .) | join(" ")' || echo "")
    secrets=$(echo "${build}" | jq -r '.secrets // [] | map("--secret id=" + .id + "," + "src=" + .src) | join(" ")' || echo "")

    if [ "$repo" == "null" ]; then
      echo "docker_repo must be set for every image. The value should be unique across the images in builds"
      exit 1
    fi

    build "${path}" "${dockerfile}" "${repo}" "${publish}" "${args}" "${secrets}" &
    build_pids+=($!)
  done
  # Waiting on a specific PID makes the wait command return with the exit
  # status of that process. Because of the 'set -e' setting, any exit status
  # other than zero causes the current shell to terminate with that exit
  # status as well.
  for pid in "${build_pids[@]}"; do
    wait "$pid"
  done
else
  if [ -f .resinci.yml ]; then
    publish=$(yq r .resinci.yml 'docker.publish')
  else
    publish=true
  fi

  # build default (no .resinci.yml)
  build . Dockerfile "$(cat < .git/.version | jq -r '.base_org + "/" + .base_repo')" "${publish}" "" ""
fi

echo "========== Build finished =========="

if [ -f docker-compose.test.yml ] && [ -f docker-compose.yml ]; then
  sut=$(yq read repo.yml 'sut')
  if [ "${sut}" == "null" ]; then
    sut="sut"
  fi
  docker-compose \
    -f docker-compose.yml \
    -f docker-compose.test.yml \
    up \
    --exit-code-from "${sut}"
fi

echo "========== Tests finished =========="

printf "\e[1;35mDEPRECATION NOTICE: please update your Dockerfiles\e[0m\n"
printf "\n"
printf "\e[1;33m* NPM_TOKEN environment variable will be removed from the default build-args\e[0m\n"
printf "\e[1;33m* use Docker BuildKit --secret workflow instead in .resinci.yml\e[0m\n"
printf "\e[1;33m* https://docs.docker.com/develop/develop-images/build_enhancements/\e[0m\n"

# Ensure we explicitly exit so we catch the signal and shut down
# the daemon. Otherwise this container will hang until it's
# killed.
exit
