#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
ARGV_TYPE="$2"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}
detectorist .

echo "ARGV_TYPE"
