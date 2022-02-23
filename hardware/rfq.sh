#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd rfq
npm install
npm link --force
popd

pushd $ARGV_DIRECTORY

prNumber=$(jq -r '.number' .git/.version)
commitID=$(jq -r '.sha' .git/.version)

rfq generate . -o ../outputs -r ${prNumber} -c ${commitID}
