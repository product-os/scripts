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

store_image() {
  local image="$1"

  sha_image="$(image_variant "${image}" "${sha}")"
  branch_image="$(image_variant "${image}" "${branch_tag}")"
  # master_image="$(image_variant "${image}" master)"
  # latest_image="$(image_variant "${image}" latest)"
  output_tar="$(sanitise_image_name "${branch_image}").tar"

  skopeo copy --format v2s2 --all "oci-archive:${DOCKER_IMAGE_CACHE}/${output_tar}" "docker://${sha_image}"
  skopeo copy --format v2s2 --all "oci-archive:${DOCKER_IMAGE_CACHE}/${output_tar}" "docker://${branch_image}"
}

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

    if [ "${repo}" == "null" ]; then
        repo="${base_org}/${base_repo}"
        echo "WARNING!!! .docker repo not set. Using '${repo}' as repo"
    fi

    if [ "${publish}" != "false" ]; then
      store_image "${repo}"
    fi
  done

else
  if [ -f .resinci.yml ]; then
    publish=$(yq e '.docker.publish' .resinci.yml)
  else
    publish=true
  fi

  if [ "$publish" != "false" ]; then
    store_image "${base_org}/${base_repo}"
  fi

fi
