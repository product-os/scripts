#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

pushd ${ARGV_DIRECTORY}

if ls .versionbot/contracts/*.tpl.yml 1> /dev/null 2>&1; then
  exit 0
else
  exit 1
fi
