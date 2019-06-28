#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

baseBranch=$(jq -r '.base_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)

mergeSHA=$(git rev-parse HEAD)

# We assume the dev branch got merged into the current one, this implies that
# the first parent is the old HEAD on the target branch and the second is the HEAD
# on the dev one
parentSHA=$(git rev-parse ${mergeSHA}^2)
oldMaster=$(git rev-parse ${mergeSHA}^1)
if [ "${parentSHA}" == "" ]; then
  echo "Could not find parent SHA. The HEAD commit on master might not be a merge"
  exit 1
fi

git branch -r

buildBranch=$(git branch -r | grep ".*${parentSHA}$" | sed 's/origin\///g')

echo '{}' | jq \
  --arg mergeSha "${mergeSHA}"  \
  --arg parentSha "${parentSHA}"  \
  --arg buildBranch "${buildBranch}"  \
  --arg oldMaster "${oldMaster}" \
  '{buildBranch: $buildBranch, parentSha: $parentSha, mergeSha: $mergeSha, oldMaster: $oldMaster }' \
  > .git/.versionist

popd

cp -ar $ARGV_DIRECTORY/. annotated-source/.
