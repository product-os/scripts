#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

#[[ "${DEBUG}" == "false" ]] || set -x


pushd $ARGV_DIRECTORY

#For now, just put a placeholder in the release - we need to be able to automatically generate the artifacts first
mkdir  -p ../outputs 
touch ../outputs/placeholder.txt
