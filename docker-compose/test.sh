#!/bin/bash

# start docker daemon
source /docker-lib.sh
start_docker

echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

sanitise_image_name() {
  echo ${1//[^a-zA-Z0-9_-]/-}
}

import_image() {
  local image_name="$1"
  local sanitised_image_name=$(sanitise_image_name "${image_name}")
  docker load < "$CONCOURSE_WORKDIR/image-cache/${sanitised_image_name}"
}

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONCOURSE_WORKDIR=$(pwd)

pushd $ARGV_DIRECTORY

[[ -f docker-compose.test.yml ]] || exit 0

base_org=$(cat .git/.version | jq -r '.base_org')
base_repo=$(cat .git/.version | jq -r '.base_repo')

# Read the details of what we should build from .resinci.yml
builds=$(${HERE}/../shared/resinci-read.sh \
  -b $(pwd) \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  for build in ${builds}; do
    repo=$((echo ${build} | jq -r '.docker_repo') || \
      (echo "${base_org}/${base_repo}"))
    import_image "$repo"
  done
else
  import_image "${base_org}/${base_repo}"
fi

sut=$(yq read repo.yml 'sut')

if [ "${sut}" == "null" ]; then
  sut="sut"
fi

COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.yml -f docker-compose.test.yml up --exit-code-from "${sut}"
