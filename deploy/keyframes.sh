#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

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
