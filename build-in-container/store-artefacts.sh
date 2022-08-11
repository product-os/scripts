#!/bin/bash

ASSETS=$(find $(pwd)/artefacts -type f)

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd resinci-deploy
npm install
npm link
popd

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

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

resinci-deploy store github-release $ASSETS \
  --branch=$headBranch \
  --owner=$org \
  --repo=$repo \
  --version=$version
