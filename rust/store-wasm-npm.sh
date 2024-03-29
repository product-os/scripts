#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Exit early if wasm should not be published
[[ "$(yq e '.type' repo.yml)" == "rust-public-crate-wasm" ]] || exit 0

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
