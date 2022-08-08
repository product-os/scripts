#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

pushd ${ARGV_DIRECTORY}

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

if ls .versionbot/contracts/*.tpl.yml 1> /dev/null 2>&1; then
  exit 0
else
  exit 1
fi
