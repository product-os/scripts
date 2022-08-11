#!/bin/bash

set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARGV_DIRECTORY="$1"
ARGV_EVENT="$2"

# hard stop if disabled
if [[ -f "${ARGV_DIRECTORY}/.resinci.yml" ]]; then
    disabled="$(cat < "${ARGV_DIRECTORY}/.resinci.yml" | yq e - -j | jq -r .disabled)"
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

detected_type="$(${HERE}/detect-event-type.sh "${ARGV_DIRECTORY}")"

test "${detected_type}" == "$ARGV_EVENT"
