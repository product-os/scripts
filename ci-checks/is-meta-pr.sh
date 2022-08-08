#!/bin/bash

echo "TASKINFO: Check if any commit contains a meta tag"

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

baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
number=$(jq -r '.number' .git/.version)

COMMITS=$(find-commits parsed -r ${baseRepo} -o ${baseOrg} -n ${number})

echo $COMMITS

IS_META_COMMIT=$(echo ${COMMITS} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Change-type:"))) | length > 0 and all(contains("none"))')

[[ ${IS_META_COMMIT} == "true" ]]
