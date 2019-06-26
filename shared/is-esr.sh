#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
[ -f repo.yml ] || exit 1

esr="$(yq r repo.yml 'esr.version')"

[[ "${esr}" != "null" ]] || exit 1
