#!/bin/bash
set -e
ARGV_DIRECTORY="$1"
set -u

# [[ "${DEBUG}" == "false" ]] || set -x
#
# pushd ${ARGV_DIRECTORY}
#
# baseRepo=$(jq -r '.base_repo' .git/.version)
# baseOrg=$(jq -r '.base_org' .git/.version)
# number=$(jq -r '.number' .git/.version)

baseRepo="find-commits"
baseOrg="balena-io-modules"
number="1"

COMMITS=$(find-commits parsed -r ${baseRepo} -o ${baseOrg} -n ${number})
IS_META_COMMIT=$(echo ${COMMITS} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Change-type:"))) | all(contains("meta"))'
[[ $IS_META_COMMIT == "true" ]]
