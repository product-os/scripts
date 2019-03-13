#!/bin/bash
[[ "${DEBUG}" == "false" ]] || set -x
ls -lah
pushd source
ls -lah
shopt -s nocaseglob
if ls readme*; then
  echo "Found file 'readme*'" 1>&2
  exit
fi
echo "Non-optional file 'readme*' missing" 1>&2
exit 1
