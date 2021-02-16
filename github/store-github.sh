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
prNumber=$(jq -r '.number' .git/.version)

if [ "${version}" == "null" ]; then
  echo "No .componentVersion found in .git/.version; not versioning"
  exit 1
fi

popd
pushd resinci-deploy > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

resinci-deploy generate contracts .versionbot/contracts \
  -v ${version}

files=$(git ls-files -mo --exclude-standard | tr '\n' ' ')

if [ "${files}" == "" ]; then
  exit 1
fi

resinci-deploy store github ${files} \
  -v v${version} \
  --base_owner=${baseOwner} \
  --base_repo=${baseRepo} \
  --head_owner=${headOwner} \
  --head_repo=${headRepo} \
  --head_branch=${headBranch}

# PR the contract file to the platform repo
contract=$(find . -type f \( -iname balena.yml -o -iname balena.cue \) -exec basename {} \;)

if [ "${contract}" == "" ]; then
  exit 0
fi

resinci-deploy pr contract ${contract} \
  --source_repo=${baseRepo} \
  --source_pr_number=${prNumber} \
  --target_owner=${baseOwner} \
  --target_repo=${baseOwner}
