#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}
base=$(jq -r '.base_branch' .git/.version )

[[ "${base}" == "master" ]]
