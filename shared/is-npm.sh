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
[[ -f package.json ]] || exit 1
[[ "$(jq '.private' package.json)" == "true" ]] && exit 1

# If we made it through the checks, exit successfully
exit 0
