#!/bin/bash

echo "TASKINFO: Check if the repo has a valid license"
set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd source

uri=$(jq -r '.uri' .git/.version)
isFork=$(scrutinizer remote ${uri} | jq -r '.fork')

# If repo is a fork it might have a different license we can't change
[[ $isFork == "true" ]] && exit 0

shopt -s nocaseglob
if ls license*; then
  echo "Found file 'license*'" 1>&2
  apk add --no-cache grep > /dev/null
  echo "Running regex test" 1>&2
  # Only fail if license is present but not one of the specified ones
  egrep -zoi '(apache.*2.0|affero general public license)' license*
  exit
fi
