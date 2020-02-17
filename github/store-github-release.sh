#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

popd

pushd resinci-deploy
npm install
npm link --force
popd

ASSETS=$(find "outputs/" -type f)

echo $ASSETS

resinci-deploy store github-release "${ASSETS}" \
  -b ${headBranch} \
  -r ${repo} \
  -o ${org} \
  -v ${version}
