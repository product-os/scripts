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
baseOwner=$(jq -r '.base_org' .git/.version)
headRepo=$(jq -r '.head_repo' .git/.version)
headOwner=$(jq -r '.head_org' .git/.version)
headBranch=$(jq -r '.head_branch' .git/.version)

version="$(yq e '.esr.version' repo.yml).0"
lines="$(yq e '.esr.line' repo.yml)"
sed "4i# ${version}\n## ($(date +%F))\n\n* Declared ESR ${line}\n" CHANGELOG.md
echo ${version} > VERSION

resinci-deploy store github CHANGELOG.md VERSION \
  -v v${version} \
  --base_owner=${baseOwner} \
  --base_repo=${baseRepo} \
  --head_owner=${headOwner} \
  --head_repo=${headRepo} \
  --head_branch=${headBranch}
  --skip-build-branch
