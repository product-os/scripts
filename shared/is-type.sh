#!/bin/bash

set -e
ARGV_TYPE="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd source

IS_TYPE=$(detectorist . | jq -r ".\"${ARGV_TYPE}\"")

[[ $IS_TYPE == "true" ]]
