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

sha=$(git rev-parse HEAD)
branch=$(cat .git/.version | jq -r '.head_branch')
branch=${branch//[^a-zA-Z0-9_-]/-}

function build() {
  path=$1; shift
  DOCKERFILE=$1; shift
  DOCKER_IMAGE=$1; shift
  publish=$1; shift
  args=$1; shift

  (
    cd $path

    if [ "${publish}" != "false" ]; then
      docker pull ${DOCKER_IMAGE}:${sha} \
        || docker pull ${DOCKER_IMAGE}:${branch} \
        || docker pull ${DOCKER_IMAGE}:master \
        || true
    fi

    docker build \
      --cache-from ${DOCKER_IMAGE}:${sha} \
      --cache-from ${DOCKER_IMAGE}:${branch} \
      --cache-from ${DOCKER_IMAGE}:master \
      ${args} \
      --build-arg RESINCI_REPO_COMMIT=${sha} \
      --build-arg CI=true \
      -t ${DOCKER_IMAGE} \
      -f ${DOCKERFILE} .

    docker tag ${DOCKER_IMAGE} ${DOCKER_IMAGE}:latest
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
    repo=$((echo ${build} | jq -r '.docker_repo') || \
      (cat .git/.version | jq -r '.base_org + "/" + .base_repo'))
    dockerfile=$((echo ${build} | jq -r '.dockerfile') || echo Dockerfile)
    path=$((echo ${build} | jq -r '.path') || echo .)
    publish=$((echo ${build} | jq -r '.publish') || echo true)
    args=$((echo ${build} | jq -r '.args // [] | map("--build-arg " + .) | join(" ")') || echo "")

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

# Ensure we explicitly exit so we catch the signal and shut down
# the daemon. Otherwise this container will hang until it's
# killed.
exit
