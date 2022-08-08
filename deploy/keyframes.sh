#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
taggedVersion=$(git log -1 --pretty=%B)
version=${taggedVersion:1}

contracts=$(find .versionbot/contracts -type f -name ${version}.*)
if [ "$contracts" == "" ]; then
  echo "No contracts matching published version"
  exit 1
fi

popd
pushd resinci-deploy
npm install
npm link
popd

pushd $ARGV_DIRECTORY

# We need to determine the correct product repo to generate a keyframe for
# For now we fix this to jellyfish-product
productRepo="jellyfish-product"
productRepoOwner="balena-io"

resinci-deploy generate keyframes "$contracts" -r $productRepo -o $productRepoOwner
