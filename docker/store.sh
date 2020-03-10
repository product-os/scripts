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

ls $(pwd)/image-cache

import_image() {
  local image_name="$1"
  docker load < "$CONCOURSE_WORKDIR/image-cache/${image_name}"
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONCOURSE_WORKDIR=$(pwd)

pushd $ARGV_DIRECTORY

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

    import_image "$dockerfile"
  done

else
  if [ -f .resinci.yml ]; then
    publish=$(yq r .resinci.yml 'docker.publish')
  else
    publish=true
  fi

  import_image "Dockerfile"
fi

docker images
