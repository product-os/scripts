#!/bin/bash
set -ex
ARGV_DIRECTORY="$1"
set -u

cd $ARGV_DIRECTORY

version=$(jq -r '.version' package.json)

repo=$(jq -r '.base_repo' .git/.version)

npm pack

mv ${repo}-${version} build
