#!/usr/bin/env bash

##############################################################
#                                                            #
# !!! [ShellCheck](https://www.shellcheck.net/) YOUR WORK!!! #
#                                                            #
#                  (please and thank you)                    #
#                                                            #
##############################################################


docker_registry_mirror=${DOCKER_REGISTRY_MIRROR:-https://registry-cache-internal.balena-cloud.com}
export docker_registry_mirror

# shellcheck disable=SC1091
source /docker-lib.sh
start_docker "" "${docker_registry_mirror}"

echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

function image_variant() {
  local docker_image
  docker_image=$1
  local docker_tag
  docker_tag=${2:-default}

  if [[ "${docker_tag}" == 'default' ]]; then
    echo "${docker_image}"
    return
  fi

  image_variant="$(echo "${docker_image}" | awk -F':' '{print $2}')"
  docker_image="$(echo "${docker_image}" | awk -F':' '{print $1}')"

  if [[ "${image_variant}" == '' ]]; then
    echo "${docker_image}:${docker_tag}"
  else
    echo "${docker_image}:${image_variant}-${docker_tag}"
  fi
}

store_image() {
  local image="$1"
  docker tag "$(image_variant "${image}")" "$(image_variant "${image}" "${sha}")"
  docker tag "$(image_variant "${image}")" "$(image_variant "${image}" "${branch_tag}")"

  docker push "$(image_variant "${image}" "${sha}")"
  docker push "$(image_variant "${image}" "${branch_tag}")"
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/image-cache.sh"

CONCOURSE_WORKDIR=$(pwd)
DOCKER_IMAGE_CACHE="${CONCOURSE_WORKDIR}/image-cache"
pushd "${ARGV_DIRECTORY}"

base_org="$(cat < .git/.version | jq -r '.base_org')"
base_repo="$(cat < .git/.version | jq -r '.base_repo')"
base_branch="$(cat < .git/.version | jq -r '.head_branch')"
sha="$(git rev-parse HEAD)"
base_branch=${base_branch//[^a-zA-Z0-9_-]/-}
branch_tag="build-"${base_branch}

# Read the details of what we should build from .resinci.yml
builds=$("${HERE}"/../shared/resinci-read.sh \
  -b "$(pwd)" \
  -l docker \
  -p builds | jq -c '.[]')

if [ -n "$builds" ]; then
  for build in ${builds}; do
    echo "${build}"
    publish=$( (echo "${build}" | jq -r '.publish') || echo true )

    repo=$(echo "${build}" | jq -r '.docker_repo')
    if [ "$repo" == "null" ]; then
        repo="${base_org}/${base_repo}"
        echo "WARNING!!! .docker repo not set. Using '$repo' as repo"
    fi

    if [ "$publish" != "false" ]; then
      import_image "$repo" "${DOCKER_IMAGE_CACHE}"
      store_image "$repo"
    fi
  done

else
  if [ -f .resinci.yml ]; then
    publish=$(yq r .resinci.yml 'docker.publish')
  else
    publish=true
  fi

  if [ "$publish" != "false" ]; then
    import_image "${base_org}/${base_repo}" "${DOCKER_IMAGE_CACHE}"
    store_image "${base_org}/${base_repo}"
  fi

fi
