#!/bin/bash

set -ex
ARGV_DIRECTORY="$1"
set -u

pushd "$ARGV_DIRECTORY"
action="$(yq r .git/.version 'action')"

set -o pipefail
[[ "${action}" != "merged" ]]
