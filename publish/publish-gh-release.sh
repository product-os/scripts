#!/bin/bash

echo "TASKINFO: Promote draft release and rename with name of final version"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

[[ -f repo.yml ]] || exit 0

# If release is not set to github we exit
[[ "$(yq read repo.yml 'release')" == "github" ]] || exit 0

owner=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)

popd

pushd resinci-deploy

npm install > /dev/null
npm link > /dev/null

popd
pushd $ARGV_DIRECTORY

resinci-deploy publish github-release \
  -r ${repo} \
  -o ${owner} \
  -b ${buildBranch} \
  -v ${version}

resinci-deploy editLatest github-release \
  -r ${repo} \
  -o ${owner} \
  -v ${version} \
  -p 0
