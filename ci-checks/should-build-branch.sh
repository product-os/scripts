#!/bin/bash

echo "TASKINFO: Check if the base branch of the PR is the master branch"

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

base=$(jq -r '.base_branch' .git/.version )
baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
number=$(jq -r '.number' .git/.version)

# If the PR is targeting master then we exit with success
[[ "${base}" == "master" ]] && exit 0

# Check if the branch is or is being declared as ESR
esr="$(yq e '.esr.version' repo.yml)"
[[ "${esr}" != "null" ]] && exit 0

# Otherwise we check if a meta footer exists, and fail if not
COMMITS=$(find-commits parsed -r ${baseRepo} -o ${baseOrg} -n ${number})

IS_META_COMMIT=$(echo ${COMMITS} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Change-type:"))) | length > 0 and all(contains("none"))')

[[ ${IS_META_COMMIT} == "true" ]]
