#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(yq r .git/.version 'action')"
branch="$(yq r .git/.version 'base_branch')"

set -o pipefail
[[ "${branch}" == "master" ]] && [[ "${action}" == "merged" ]]
