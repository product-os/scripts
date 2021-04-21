#!/bin/bash

source /docker-lib.sh
start_docker

echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/image-cache.sh"

CONCOURSE_WORKDIR=$(pwd)
DOCKER_IMAGE_CACHE="${CONCOURSE_WORKDIR}/image-cache"
pushd $ARGV_DIRECTORY

# Enable buildkit and prepare npmtoken secret file
export DOCKER_BUILDKIT=1
echo $NPM_TOKEN > npmtoken
export NPM_TOKEN_PATH="$(pwd)/npmtoken"

sha=$(cat .git/.version | jq -r '.sha')
branch=$(cat .git/.version | jq -r '.head_branch')
branch=${branch//[^a-zA-Z0-9_-]/-}
owner=$(cat .git/.version | jq -r '.base_org')
repo=$(cat .git/.version | jq -r '.base_repo')

chamber export --format dotenv "concourse/test-runtime-secrets/repos/${owner}/${repo}" -o runtime-secrets

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

if [ -s runtime-secrets ]; then
  while IFS= read -r -d $'\n'
  do
    export "$REPLY"
  done < runtime-secrets
fi

rm -rf runtime-secrets

# register qemu binfmt for automatic emulated arm builds
# The `--reset` flag is intentionally not used, to avoid a race condition with
# any ongoing builds on the VM (that could result in `exec format error`).
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 -p yes

function image_variant() {
  local docker_image=$1
  local docker_tag=${2:-default}

  if [[ "${docker_tag}" == 'default' ]]; then
    echo "${docker_image}"
    return
  fi

  local image_variant="$(echo "${docker_image}" | awk -F':' '{print $2}')"
  local docker_image="$(echo "${docker_image}" | awk -F':' '{print $1}')"

  if [[ "${image_variant}" == '' ]]; then
    echo "${docker_image}:${docker_tag}"
  else
    echo "${docker_image}:${image_variant}-${docker_tag}"
  fi
}

function build() {
  path=$1; shift
  DOCKERFILE=$1; shift
  DOCKER_IMAGE=$1; shift
  publish=$1; shift
  args=$1; shift

  (
    cd $path

    if [ "${publish}" != "false" ]; then
      docker pull $(image_variant ${DOCKER_IMAGE} ${sha}) \
        || docker pull $(image_variant ${DOCKER_IMAGE} ${branch}) \
        || docker pull $(image_variant ${DOCKER_IMAGE} master) \
        || true
    fi

    docker build \
      --cache-from $(image_variant ${DOCKER_IMAGE} ${sha}) \
      --cache-from $(image_variant ${DOCKER_IMAGE} ${branch}) \
      --cache-from $(image_variant ${DOCKER_IMAGE} master) \
      ${args} \
      --build-arg RESINCI_REPO_COMMIT=${sha} \
      --build-arg CI=true \
      --secret id=npmtoken,src=${NPM_TOKEN_PATH} \
      -t ${DOCKER_IMAGE} \
      -f ${DOCKERFILE} .

    docker tag $(image_variant ${DOCKER_IMAGE}) $(image_variant ${DOCKER_IMAGE} latest) || true
    docker tag $(image_variant ${DOCKER_IMAGE} latest) $(image_variant ${DOCKER_IMAGE} latest)
    export_image "${DOCKER_IMAGE}" "${DOCKER_IMAGE_CACHE}"
  )
}

# Read the details of what we should build from .resinci.yml
builds=$(${HERE}/../shared/resinci-read.sh \
  -b $(pwd) \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  build_pids=()
  for build in ${builds}; do
    echo ${build}
    repo=$(echo ${build} | jq -r '.docker_repo')
    dockerfile=$((echo ${build} | jq -r '.dockerfile') || echo Dockerfile)
    path=$((echo ${build} | jq -r '.path') || echo .)
    publish=$((echo ${build} | jq -r '.publish') || echo true)
    args=$((echo ${build} | jq -r '.args // [] | map("--build-arg " + .) | join(" ")') || echo "")

    if [ "$repo" == "null" ]; then
      echo "docker_repo must be set for every image. The value should be unique across the images in builds"
      exit 1
    fi

    build "$path" "$dockerfile" "$repo" "$publish" "$args" &
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

  build . Dockerfile $(cat .git/.version | jq -r '.base_org + "/" + .base_repo') $publish ""
fi

echo "========== Build finished =========="

if [ -f docker-compose.test.yml ]; then
  sut=$(yq read repo.yml 'sut')
  if [ "${sut}" == "null" ]; then
    sut="sut"
  fi
  COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.yml -f docker-compose.test.yml up --exit-code-from "${sut}"
fi

echo "========== Tests finished =========="

# Ensure we explicitly exit so we catch the signal and shut down
# the daemon. Otherwise this container will hang until it's
# killed.
exit
