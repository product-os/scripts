#!/usr/bin/env bash

set -a

docker_registry_mirror=${DOCKER_REGISTRY_MIRROR:-https://registry-cache-internal.balena-cloud.com}

curl -I --fail --max-time 5 "${docker_registry_mirror}" || unset docker_registry_mirror

# shellcheck disable=SC1091
source /docker-lib.sh
start_docker 3 5 "" "${docker_registry_mirror}"

docker --version

log_in "${DOCKER_USERNAME}" "${DOCKER_PASSWORD}"
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/image-cache.sh"

CONCOURSE_WORKDIR=$(pwd)
DOCKER_IMAGE_CACHE="${CONCOURSE_WORKDIR}/image-cache"
pushd "${ARGV_DIRECTORY}"

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml" >&2
        exit 1
    fi
fi

# hard stop if Flowzone is enabled
if grep -Eqr '\s+uses:\sproduct-os\/flowzone\/\.github\/workflows\/.*' "$(pwd)/.github/workflows/"; then
    echo "Flowzone already enabled, disabling resinCI" >&2
    echo "see, https://github.com/product-os/flowzone" >&2
    exit 1
fi

tmptoken=$(mktemp)
echo "${NPM_TOKEN}" > "${tmptoken}"

sha=$(cat < .git/.version | jq -r '.sha')
branch=$(cat < .git/.version | jq -r '.head_branch')
branch=${branch//[^a-zA-Z0-9_-]/-}
owner=$(cat < .git/.version | jq -r '.base_org')
source_repo=$(cat < .git/.version | jq -r '.base_repo')

# (TBC) remove once everything is migrated to balena-secrets/git-secret workflow, also:
# git@github.com:product-os/ci-images.git
# git@github.com:product-os/scripts.git
chamber export \
  --format dotenv "concourse/test-runtime-secrets/repos/${owner}/${source_repo}" \
  --output-file runtime-secrets || true

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

# create fresh buildx builder instance
docker buildx create --driver docker-container --use
# force build container creation to avoid unique name generation issues
echo "FROM scratch" | docker buildx build -

function build_with_opts() {
    local dockerfile=$1; shift
    local build_stages
    build_stages="$(grep -Ei '^FROM\s+.*\s+AS\s+.*$' "${dockerfile}" | tr '[:upper:]' '[:lower:]' | awk -F' as ' '{print $2}')"

    # multistage build handling
    for stage in ${build_stages}; do
      docker buildx build --target "${stage}" "$@"
    done

    # single-stage build handling and runtime stage
    docker buildx build "$@"
}

function build() {
  path=$1; shift
  DOCKERFILE=$1; shift
  DOCKER_IMAGE=$1; shift
  publish=$1; shift
  args=$1; shift
  secrets=$1; shift
  platforms=$1; shift

  sha_image="$(image_variant "${DOCKER_IMAGE}" "${sha}")"
  branch_image="$(image_variant "${DOCKER_IMAGE}" "build-${branch}")"
  master_image="$(image_variant "${DOCKER_IMAGE}" master)"
  latest_image="$(image_variant "${DOCKER_IMAGE}" latest)"
  output_tar="$(sanitise_image_name "${branch_image}").tar"

  # read platforms to an array
  platform_arr=()
  if [ -n "${platforms}" ]
  then
    platform_arr=(--platform "${platforms}")
  fi

  cache_from_arr=()
  for image in "${sha_image}" "${branch_image}" "${master_image}" "${latest_image}"
  do
    cache_from_arr+=(--cache-from "${image}")
  done

  (
    cd "${path}"

    # shellcheck disable=SC2086
    build_with_opts \
      "${DOCKERFILE}" \
      --progress=plain \
      "${cache_from_arr[@]}" \
      ${args} \
      --build-arg RESINCI_REPO_COMMIT="${sha}" \
      --build-arg CI=true \
      --build-arg NPM_TOKEN="${NPM_TOKEN}" \
      ${secrets} \
      "${platform_arr[@]}" \
      --secret id=npmtoken,src="${tmptoken}" \
      --file "${DOCKERFILE}" . \
      --output "type=oci,dest=${output_tar}"

    # load the native platform (amd64) image to the local daemon for testing
    skopeo copy "oci-archive:${output_tar}" "docker-daemon:${latest_image}"

    # Scan the image with trivy and output to stdout
    epoch=$(date +%s%N)
    trivy image -f json -o "${epoch}.json" \
      --no-progress \
      --exit-code 0 \
      --severity HIGH \
      --ignore-unfixed \
      --timeout 10m \
      "${latest_image}" || echo "Ignoring trivy call failure"
    curl --location --request POST 'https://cln596sf9k.execute-api.us-east-1.amazonaws.com/default/trivy-scan-output' \
      --header "auth: ${TRIVY_SCAN_TOKEN}" \
      --header "imagename: ${latest_image}" \
      --header "repoowner: ${owner}" \
      --header "reponame: ${source_repo}" \
      --header 'Content-Type: application/json' \
      --data "@${epoch}.json"
    rm "${epoch}.json" || echo "Ignoring missing trivy file failure"

    if [ "$publish" != "false" ]; then
      cp -v "${output_tar}" "${DOCKER_IMAGE_CACHE}/${output_tar}"
    fi
    rm "${output_tar}"
  )
}

max_parallel_builds=2

# Read the details of what we should build from .resinci.yml
builds=$("${HERE}/../shared/resinci-read.sh" \
  -b "$(pwd)" \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  for build in ${builds}; do
    echo "${build}"
    repo=$(echo "${build}" | jq -r '.docker_repo')
    dockerfile=$(echo "${build}" | jq -r '.dockerfile' || echo Dockerfile)
    path=$(echo "${build}" | jq -r '.path' || echo .)
    publish=$(echo "${build}" | jq -r '.publish' || echo true)
    args=$(echo "${build}" | jq -r '.args // [] | map("--build-arg " + .) | join(" ")' || echo "")
    secrets=$(echo "${build}" | jq -r '.secrets // [] | map("--secret id=" + .id + "," + "src=" + .src) | join(" ")' || echo "")
    platforms="$(echo "${build}" | jq -r '.platforms // [] | join(",")' || echo "")"

    if [ "$repo" == "null" ]; then
      echo "docker_repo must be set for every image. The value should be unique across the images in builds"
      exit 1
    fi

    build "${path}" "${dockerfile}" "${repo}" "${publish}" "${args}" "${secrets}" "${platforms}"
  done
else
  if [ -f .resinci.yml ]; then
    publish=$(yq e '.docker.publish' .resinci.yml)
  else
    publish=true
  fi

  # build default (no .resinci.yml)
  build . Dockerfile "$(cat < .git/.version | jq -r '.base_org + "/" + .base_repo')" "${publish}" "" "" ""
fi

echo "========== Build finished =========="

if [ -f docker-compose.test.yml ] && [ -f docker-compose.yml ]; then
  sut=$(yq e '.sut' repo.yml)
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
