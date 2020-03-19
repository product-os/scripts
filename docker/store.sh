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

store_image() {
  local image="$1"
  docker tag ${image}:latest ${image}:${sha}
  docker tag ${image}:latest ${image}:${base_branch}

  docker push ${image}:${sha}
  docker push ${image}:${base_branch}
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/image-cache.sh"

CONCOURSE_WORKDIR=$(pwd)
DOCKER_IMAGE_CACHE="${CONCOURSE_WORKDIR}/image-cache"
pushd $ARGV_DIRECTORY

base_org=$(cat .git/.version | jq -r '.base_org')
base_repo=$(cat .git/.version | jq -r '.base_repo')
base_branch=$(cat .git/.version | jq -r '.head_branch')
sha=$(git rev-parse HEAD)
base_branch=${base_branch//[^a-zA-Z0-9_-]/-}

# Read the details of what we should build from .resinci.yml
builds=$(${HERE}/../shared/resinci-read.sh \
  -b $(pwd) \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  for build in ${builds}; do
    echo ${build}
    repo=$((echo ${build} | jq -r '.docker_repo') || \
      (echo "${base_org}/${base_repo}"))
    dockerfile=$((echo ${build} | jq -r '.dockerfile') || echo Dockerfile)
    path=$((echo ${build} | jq -r '.path') || echo .)
    publish=$((echo ${build} | jq -r '.publish') || echo true)
    args=$((echo ${build} | jq -r '.args // [] | map("--build-arg " + .) | join(" ")') || echo "")

    import_image "$repo" "${DOCKER_IMAGE_CACHE}"
    store_image "$repo"
  done

else
  if [ -f .resinci.yml ]; then
    publish=$(yq r .resinci.yml 'docker.publish')
  else
    publish=true
  fi

  import_image "${base_org}/${base_repo}" "${DOCKER_IMAGE_CACHE}"
  store_image "${base_org}/${base_repo}"

fi
