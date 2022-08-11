#!/bin/bash

echo "TASKINFO: Will push version commit stored in the build branch to master"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

owner=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)

if [ "${buildBranch}" == "" ]; then
  echo "'.buildBranch' expected in .git/.versionist; something went wrong"
  exit 1
fi

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
  -b ${buildBranch}

resinci-deploy clean github ${buildBranch} \
  -o ${owner} \
  -r ${repo}
