#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

npm install -g detectorist@0.6.0

pushd $ARGV_DIRECTORY

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml" >&2
        exit 1
    fi
fi

# hard stop if Flowzone is enabled
if grep -Eqr '\s+uses:\sproduct-os\/flowzone\/\.github\/workflows\/.*' "$(pwd)/.github/workflows/"; then
    echo "Flowzone already enabled, disabling resinCI" >&2
    echo "see, https://github.com/product-os/flowzone" >&2
    exit 1
fi

baseBranch=$(jq -r '.base_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
isDocker=$(detectorist . | jq -r '.docker')
privateRepo=false
if curl https://github.com/$org/$repo -I | grep 'Status: 404'; then
  privateRepo=true
fi

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
if [ "${buildBranch}" == "" ]; then
  echo "Could not find build branch. Did you merge before the branch was built?"
  exit 1
fi

echo '{}' | jq \
  --arg mergeSha "${mergeSHA}"  \
  --arg parentSha "${parentSHA}"  \
  --arg buildBranch "${buildBranch}"  \
  --arg isDocker "${isDocker}" \
  --arg oldMaster "${oldMaster}" \
  --arg privateRepo "${privateRepo}" \
  '{buildBranch: $buildBranch, parentSha: $parentSha, mergeSha: $mergeSha,
privateRepo: $privateRepo, languages: { docker: $isDocker }, oldMaster: $oldMaster }' \
  > .git/.versionist

popd

cp -ar $ARGV_DIRECTORY/. annotated-source/.
