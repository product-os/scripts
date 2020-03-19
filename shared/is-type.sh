#!/bin/bash

set -e
ARGV_TYPE="$1"
ARGV_DIRECTORY="$2"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

if [ -f repo.yml ]; then
  REPO_TYPE=$(yq read repo.yml 'type')
fi

[[ $REPO_TYPE == $ARGV_TYPE ]] && exit 0

IS_TYPE=$(detectorist . | jq -r ".\"${ARGV_TYPE}\"")

[[ $IS_TYPE == "true" ]]
