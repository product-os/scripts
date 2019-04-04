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
  /usr/bin/egrep -zoi '(apache.*2.0|affero general public license)' license*
  exit
fi

echo "License is missing or not valid."
echo "Valid licenses are Apache 2.0 and Affero GPL"
