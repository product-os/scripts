#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $ARGV_DIRECTORY

# Exit early if wasm should not be published
[[ "$(yq e repo.yml 'type')" == "rust-public-crate-wasm" ]] || exit 0

headBranch=$(jq -r '.head_branch' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)
sha=$(jq -r '.sha' .git/.version)

popd
pushd resinci-deploy
npm install
npm link
popd

pushd $ARGV_DIRECTORY

# This sets PKG_DIR to the relative path of the package
BUILD_DIR="target/npm"
OUT_DIR="pkg"

"${HERE}/build-wasm-npm.sh" \
  -b ${BUILD_DIR} \
  -o ${OUT_DIR}

PKG_DIR="${BUILD_DIR}/${OUT_DIR}"

echo "Testing browser NPM package..."
wasm-pack test --chrome --firefox --headless

if [ -d "node/tests" ]; then
    echo "Testing NodeJS NPM package..."
    pushd node/tests
    npm install
    npm test
    popd
else
    echo "Skipping NodeJS NPM package tests, folder node/tests not found"
fi

pushd ${PKG_DIR}

resinci-deploy store npm . \
  -s ${sha} \
  -b ${headBranch} \
  -v ${version}
