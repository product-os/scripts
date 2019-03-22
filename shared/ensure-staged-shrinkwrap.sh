#!/bin/sh

###
# Copyright 2017 resin.io
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###

set -e

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""

while getopts ":b:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ]; then
  usage
fi

SHRINKWRAP_FILE=npm-shrinkwrap.json

if [ ! -f "$ARGV_BASE_DIRECTORY/$SHRINKWRAP_FILE" ]; then
  echo "No shrinkwrap file found. Continuing..."
  exit 0
fi

cd "$ARGV_BASE_DIRECTORY"

if [ -z $NPM_VERSION ]; then
  npm shrinkwrap --dev
else
  npx npm@$NPM_VERSION shrinkwrap --dev
fi
# We want to ignore the version bump in npm-shrinkwrap that happens on the CI
oldShrink=$(git show HEAD:${SHRINKWRAP_FILE} | jq "del(.version)")
newShrink=$(jq "del(.version)" ${SHRINKWRAP_FILE})

echo "$oldShrink" > shrinkwrap.old.tmp
echo "$newShrink" > shrinkwrap.new.tmp
DIFF=$(diff shrinkwrap.old.tmp shrinkwrap.new.tmp)
rm shrinkwrap.old.tmp
rm shrinkwrap.new.tmp

if [ "${DIFF}" != "" ]; then
  echo "There are unstaged $SHRINKWRAP_FILE changes. Please commit the result of:" 1>&2
  echo "" 1>&2
  echo "    npm shrinkwrap --dev" 1>&2
  echo "" 1>&2
  git --no-pager diff "$SHRINKWRAP_FILE"
  exit 1
fi
