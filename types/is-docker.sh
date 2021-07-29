#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/../shared/check-dependency.sh" jq
"$HERE/../shared/check-dependency.sh" yq

cd "$ARGV_DIRECTORY"

[[ -f Dockerfile ]] && exit 0
[[ -f .resinci.yml ]] || exit 1

BUILD_COUNT="$(yq e -j .resinci.yml | jq -r '.docker.builds | length')"
[[ ${BUILD_COUNT} -gt 0 ]] && exit 0

exit 1
