#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

[[ -f repo.yml ]] || exit 1

[[ "$(yq e '.type' repo.yml)" == "electron" ]] || exit 1
# If we made it through the checks, exit successfully
exit 0
