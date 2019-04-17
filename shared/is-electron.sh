#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

[[ -f repo.yml ]] || exit 1

[[ "$(yq read repo.yml 'type')" == "electron" ]] || exit 1
# If we made it through the checks, exit successfully
exit 0
