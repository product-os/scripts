#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(yq r .git/.version 'action')"

set -o pipefail
[[ "${action}" != "merged" ]]
