#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

pushd ${ARGV_DIRECTORY}

if test -f docker-compose.test.yml; then
  exit 0
else
  exit 1
fi
