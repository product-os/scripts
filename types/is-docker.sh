#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/../shared/check-dependency.sh" jq
"$HERE/../shared/check-dependency.sh" yq

cd "$ARGV_DIRECTORY"

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
else
    exit 1
fi

[[ -f Dockerfile ]] && exit 0

BUILD_COUNT="$(yq e -j .resinci.yml | jq -r '.docker.builds | length')"
[[ ${BUILD_COUNT} -gt 0 ]] && exit 0

exit 1
