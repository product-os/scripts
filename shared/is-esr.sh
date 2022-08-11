#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

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

action="$(jq -r '.action' .git/.version)"

[ -f repo.yml ] || exit 1

esr="$(yq e '.esr.version' repo.yml)"
[[ "${action}" == "merged" ]] || [[ "${action}" == "republish" ]] || exit 1
[[ "${esr}" != "null" ]] || exit 1
