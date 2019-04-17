#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

pushd ${ARGV_DIRECTORY}

[[ -f Cargo.toml ]] || exit 1

# If we made it through the checks, exit successfully
exit 0
