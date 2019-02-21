#!/bin/bash
set -ex
ARGV_DIRECTORY="$1"
set -u

cd $ARGV_DIRECTORY

version=$(jq -r '.version' package.json)
pkg_name=$(jq -r '.name' package.json)

npm pack

mv ${pkg_name}-${version}.tgz ../build
