#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(yq r .git/.version 'action')"
type="$(yq r .git/.version 'type')"

set -o pipefail
[[ "${action}" != "merged" ]] && [[ "${type}" != "VersionEvent" ]]
