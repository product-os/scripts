#!/bin/bash
set -ex
ARGV_DIRECTORY="$1"
set -u

cd $ARGV_DIRECTORY

npm install
npm test
