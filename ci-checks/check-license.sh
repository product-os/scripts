#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd source

shopt -s nocaseglob
if ls license*; then
  echo "Found file 'license*'" 1>&2
  apk add --no-cache grep > /dev/null
  echo "Running regex test" 1>&2
  # Only fail if license is present but not one of the specified ones
  /usr/bin/egrep -zoi '(apache.*2.0|affero general public license)' license*
  exit
fi
