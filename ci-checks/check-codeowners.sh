#!/bin/bash

echo "TASKINFO: Check if CODEOWNERS exists"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

shopt -s nocaseglob
if ls .github/CODEOWNERS*; then
  echo "Found CODEOWNERS file" 1>&2
  exit 1
fi

exit 0
