#!/bin/bash

echo "TASKINFO: Will publish rust-wasm package to npm"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE=$(pwd)

pushd $ARGV_DIRECTORY

[[ -f repo.yml ]] || exit 0
# If type is not rust-public-crate-wasm we should not publish
[[ "$(yq read repo.yml 'type')" == "rust-public-crate-wasm" ]] || exit 0

version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)
parentSHA=$(jq -r '.parentSha' .git/.versionist)

popd
pushd resinci-deploy
npm install > /dev/null
npm link > /dev/null
popd

pushd $ARGV_DIRECTORY

# This sets PKG_DIR to the relative path of the package
BUILD_DIR="target/npm"
OUT_DIR="pkg"

"${HERE}/build-wasm-npm.sh" \
  -b ${BUILD_DIR} \
  -o ${OUT_DIR}

PKG_DIR="${BUILD_DIR}/${OUT_DIR}"

pushd "$ARGV_DIRECTORY/${PKG_DIR}"

resinci-deploy publish npm . \
  -s ${parentSHA} \
  -b ${buildBranch} \
  -v ${version}

resinci-deploy clean npm . ${buildBranch}
