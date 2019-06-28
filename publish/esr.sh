#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

owner=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
branch=$(jq -r '.base_branch' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)

popd
pushd resinci-deploy > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

resinci-deploy publish github \
  -v v${version} \
  -o ${owner} \
  -r ${repo} \
  -b ${buildBranch} \
  -t ${branch}

resinci-deploy clean github ${buildBranch} \
  -o ${owner} \
  -r ${repo}
