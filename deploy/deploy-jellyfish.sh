#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc

pushd $ARGV_DIRECTORY

owner=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

if [ "${repo}" != "jellyfish" ]; then
  echo "Not on jellyfish, nothing to deploy"
  exit 0
fi

popd
pushd katapult > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

pushd deploy-templates
cp ./keyframe.tpl.yml ./jellyfish-product/product/keyframe.yml
sed -i "s/#JF_VERSION#/$version/g" ./jellyfish-product/product/keyframe.yml
./deploy.sh keyframe.yml
