#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}
base=$(jq -r '.base_branch' .git/.version )
baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
number=$(jq -r '.number' .git/.version)

# If the PR is targetting master then we exit with success
[[ "${base}" == "master" ]] && exit 0

# Otherwise we check if a Backport footer exists, and fail if not
COMMITS=$(find-commits parsed -r ${baseRepo} -o ${baseOrg} -n ${number})

IS_BACKPORT_COMMIT=$(echo ${COMMITS} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Backport-to:"))) | length > 0)')

[[ ${IS_BACKPORT_COMMIT} == "true" ]]
