#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd resinci-deploy

npm install > /dev/null
npm link > /dev/null

popd

pushd ${ARGV_DIRECTORY}

baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
editVersion=$(yq e '.triggerNotification.version' repo.yml)
stagingP=$(yq e '.triggerNotification.stagingPercentage' repo.yml)

resinci-deploy editLatest github-release -r ${baseRepo} -o ${baseOrg} -v ${editVersion} -p ${stagingP}
