#!/bin/bash

echo "TASKINFO: Will publish package to crates.io"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

[[ -f repo.yml ]] || exit 0

repoType=$(yq read repo.yml 'type')
# If type is not rust-public-create we should not publish
[[ "${repoType}" == "rust-public-crate" ]] || \
  [[ "${repoType}" == "rust-public-crate-wasm" ]] || exit 0

version=$(jq -r '.componentVersion' .git/.version)

echo "Publishing Rust crate..."

# We replace the version in Cargo.toml on the fly as our commit still does not have the version bump at this step
# This only replaces the first occurrence of `version = "..."`
sed -i "1,/version = \".\+\"/s/version = \".\+\"/version = \"${version}\"/" Cargo.toml

cargo publish --allow-dirty --token=${CRATES_TOKEN}
