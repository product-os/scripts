#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

# If private is true in package.json this means the package
# is not meant to be published at all.
[[ "$(jq '.private' package.json)" == "true" ]] && exit 1

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

privateRepo=false
if curl https://github.com/$org/$repo -I | grep 'Status: 404'; then
  privateRepo=true
fi

popd

pushd resinci-deploy
npm install
npm link
popd

pushd $ARGV_DIRECTORY

if /usr/bin/egrep '(preversion|postversion|prepare|prepack|postpack|publish)' package.json; then
  npm install
fi

sha=$(git rev-parse HEAD)

resinci-deploy store npm . \
  $([[ "$privateRepo" == "true" ]] && echo "--private") \
  -s ${sha} \
  -b ${headBranch} \
  -v ${version}
