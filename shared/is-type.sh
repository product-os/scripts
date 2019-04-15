#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
ARGV_TYPE="$2"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

IS_TYPE=$(detectorist . | jq -r ".${ARGV_TYPE}")

[[ $IS_TYPE == "true" ]]
