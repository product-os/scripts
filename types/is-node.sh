#!/bin/bash
set -e
ARGV_DIRECTORY="$1"
set -u

cd $ARGV_DIRECTORY

[[ -f package.json ]] || exit 1

# If we made it through the checks, exit successfully
exit 0
