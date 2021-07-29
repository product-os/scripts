#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE=$(pwd)

pushd ${ARGV_DIRECTORY}

should_run="$(${HERE}/scripts/shared/resinci-read.sh \
  -b $(pwd) \
  -l docker \
  -p run)"

[[ "${should_run}" == "false" ]] && exit 1

if [[ -f "repo.yml" ]]; then
  project_type="$(yq e repo.yml 'type')"
  # All of these types will still have a Dockerfile, but
  # should not trigger this check
  [[ "$project_type" == "generic" ]] && exit 1
  [[ "$project_type" == "docker-compose" ]] && exit 1
  [[ "$project_type" == "build-in-container" ]] && exit 1
  [[ "$project_type" == "balena-engine" ]] && exit 1
  [[ "$project_type" == "balena" ]] && exit 1
fi

[[ -f Dockerfile ]] && exit 0

[[ -f .resinci.yml ]] || exit 1

build_count=$(yq e -j .resinci.yml | jq -r '.docker.builds | length')

[[ ${build_count} -gt 0 ]] && exit 0

exit 1
