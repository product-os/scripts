#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"
action="$(jq -r '.action' .git/.version)"
branch="$(jq -r '.base_branch' .git/.version)"

set -o pipefail
[[ "${branch}" == "master" ]] && [[ "${action}" == "merged" ]]
