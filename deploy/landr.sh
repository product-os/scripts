#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)

[[ "${repo}" == "landr" ]] || exit 0
[[ "${org}" == "balena-io" ]] || exit 0

npm install -g landr && landr
