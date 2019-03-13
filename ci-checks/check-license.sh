#!/bin/bash
[[ "${DEBUG}" == "false" ]] || set -x
ls -lah
pushd source
ls -lah
shopt -s nocaseglob
if ls license*; then
  echo "Found file 'license*'" 1>&2
  apk add --no-cache grep > /dev/null
  echo "Running regex test" 1>&2
  /usr/bin/egrep -zoi '(apache.*2.0|affero general public license)' license*
  exit
