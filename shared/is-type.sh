#!/bin/bash

set -e
ARGV_TYPE="$1"
ARGV_DIRECTORY="$2"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

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

if [ -f repo.yml ]; then
  REPO_TYPE=$(yq e '.type' repo.yml)
fi

[[ $REPO_TYPE == $ARGV_TYPE ]] && exit 0

IS_TYPE=$(detectorist . | jq -r ".\"${ARGV_TYPE}\"")

[[ $IS_TYPE == "true" ]]
