#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd ${ARGV_DIRECTORY}

shopt -s nocaseglob
if ls readme*; then
  echo "Found README file" 1>&2
  exit
fi
echo "README file is missing" 1>&2
exit 1
