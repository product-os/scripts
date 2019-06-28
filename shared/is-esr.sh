#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(yq r .git/.version 'action')"

[ -f repo.yml ] || exit 1

esr="$(yq r repo.yml 'esr.version')"
[[ "${action}" == "merged" ]] || exit 1
[[ "${esr}" != "null" ]] || exit 1
