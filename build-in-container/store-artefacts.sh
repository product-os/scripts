#!/bin/bash

ASSETS=$(find $(pwd)/artefacts -type f)

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

resinci-deploy store github-release $ASSET \
  --branch=$headBranch \
  --owner=$org \
  --repo=$repo \
  --version=$version
