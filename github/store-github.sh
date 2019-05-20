#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

baseOwner=$(jq -r '.base_org' .git/.version)
baseRepo=$(jq -r '.base_repo' .git/.version)

headBranch=$(jq -r '.head_branch' .git/.version)
headOwner=$(jq -r '.head_org' .git/.version)
headRepo=$(jq -r '.head_repo' .git/.version)

version=$(jq -r '.componentVersion' .git/.version)

if [ "${version}" == "null" ]; then
  echo "No .componentVersion found in .git/.version; not versioning"
  exit 1
fi

files=$(git ls-files -mo --exclude-standard | tr '\n' ' ')

if [ "${files}" == "" ] || [ "${version}" == "null" ]; then
  exit 1
fi

set +e
updatingTemplate=$(git diff --name-only HEAD origin/master | grep contract.template.yaml || echo "" )
set -e

if [ "${updatingTemplate}" != "" ]; then
  # No need to produce a version, since we updated the template we will receive a PR from the contract universe with the new version.
  echo "Updating template. Will not store github"
  exit 0
fi

popd
pushd resinci-deploy > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

resinci-deploy store github ${files} \
  -v v${version} \
  --base_owner=${baseOwner} \
  --base_repo=${baseRepo} \
  --head_owner=${headOwner} \
  --head_repo=${headRepo} \
  --head_branch=${headBranch}

[[ -f contract.yaml ]] || exit 0

resinci-deploy store contracts contract.yaml .versionbot/contracts \
  -v ${version} \
  -b ${headBranch} \
  -o ${headOwner} \
  -r ${headRepo}
