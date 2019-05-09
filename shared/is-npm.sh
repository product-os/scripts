#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE=$(pwd)

pushd ${ARGV_DIRECTORY}

should_run="$(${HERE}/scripts/shared/resinci-read.sh \
  -b $(pwd) \
  -l npm \
  -p run)"

[[ "${should_run}" == "true" ]] && exit
[[ "${should_run}" == "false" ]] && exit 1
if [[ -f "repo.yml" ]]; then
  project_type="$(yq read repo.yml 'type')"
  # Explicitly check for electron packages as they appear as npm ones
  [[ "$project_type" == "electron" ]] && exit 1
  # Explicitly check for generic packages as they might appear as npm ones
  [[ "$project_type" == "generic" ]] && exit 1
fi
[[ -f package.json ]] || exit 1

# If we made it through the checks, exit successfully
exit 0
