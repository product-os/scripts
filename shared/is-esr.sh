#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(jq -r '.action' .git/.version)"

[ -f repo.yml ] || exit 1

esr="$(yq e repo.yml 'esr.version')"
[[ "${action}" == "merged" ]] || [[ "${action}" == "republish" ]] || exit 1
[[ "${esr}" != "null" ]] || exit 1
