#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/../shared/check-dependency.sh" jq

RUN="$("$HERE/../shared/resinci-read.sh" -b "$(pwd)" -l npm -p run)"
[[ "${RUN}" == "true" ]] && exit 0
[[ "${RUN}" == "false" ]] && exit 1

cd "$ARGV_DIRECTORY"

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

[[ -f package.json ]] || exit 1
[[ "$(jq '.private' package.json)" == "true" ]] && exit 1

# If we made it through the checks, exit successfully
exit 0
