#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

# If private is true in package.json this means the package
# is not meant to be published at all.
[[ "$(jq '.private' package.json)" == "true" ]] && exit 1

# If we made it through the checks, exit successfully
exit 0
