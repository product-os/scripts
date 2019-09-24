#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

if [[ -f "repo.yml" ]]; then
  project_type="$(yq read repo.yml 'type')"
  [[ "$project_type" == "generic" ]] && exit 1
fi

[[ -f Dockerfile ]] && exit 0

[[ -f .resinci.yml ]] || exit 1

build_count=$(yq r -j .resinci.yml | jq -r '.docker.builds | length')

[[ ${build_count} -gt 0 ]] && exit 0

exit 1
