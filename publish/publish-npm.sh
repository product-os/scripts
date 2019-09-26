#!/bin/bash

echo "TASKINFO: Will push npm package and tag it as latest"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

npm install -g detectorist@0.6.0

languages=$(detectorist .)

if [ "$(echo $languages | jq -r '.npm')" != "true" ]; then
  echo "Not an NPM module; not attempting to publish"
  exit 0
fi

version=$(jq -r '.componentVersion' .git/.version)
privateRepo=$(jq -r '.privateRepo' .git/.versionist)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)
parentSHA=$(jq -r '.parentSha' .git/.versionist)

if [ "${privateRepo}" == "" ]; then
  echo "'.privateRepo' expected in .git/.versionist; something went wrong"
  exit 1
fi

if [ "${buildBranch}" == "" ]; then
  echo "'.buildBranch' expected in .git/.versionist; something went wrong"
  exit 1
fi

if [ "${parentSHA}" == "" ]; then
  echo "'.parentSha' expected in .git/.versionist; something went wrong"
  exit 1
fi

popd
pushd resinci-deploy

npm install > /dev/null
npm link > /dev/null

popd
pushd $ARGV_DIRECTORY

apk add --no-cache grep
if /usr/bin/egrep '(preversion|postversion|prepare|prepack|postpack|publish)' package.json; then
  npm install
fi

resinci-deploy publish npm . \
  $([[ "$privateRepo" == "true" ]] && echo "--private") \
  -s ${parentSHA} \
  -b ${buildBranch} \
  -v ${version}

resinci-deploy clean npm . ${buildBranch}
