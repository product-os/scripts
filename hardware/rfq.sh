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

rfq generate . -o ../outputs
