#!/bin/bash
set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
number=$(jq -r '.number' .git/.version)

COMMITS=$(find-commits parsed -r ${baseRepo} -o ${baseOrg} -n ${number})

echo $COMMITS

IS_META_COMMIT=$(echo ${COMMITS} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Change-type:"))) | length > 0 and all(contains("none"))')

[[ ${IS_META_COMMIT} == "true" ]]
