#!/bin/bash

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

set -u
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/check-dependency.sh" jq

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -p <platform (electron|node)>" 1>&2
  echo "    -l <pipeline name>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_PLATFORM=""
ARGV_PIPELINE=""

while getopts ":b:p:l:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    p) ARGV_PLATFORM=$OPTARG ;;
    l) ARGV_PIPELINE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_PLATFORM" ] \
  || [ -z "$ARGV_PIPELINE" ]; then
  usage
fi

if [ ! -f "$ARGV_BASE_DIRECTORY/package.json" ]; then
  echo "No package.json found at $ARGV_BASE_DIRECTORY" 1>&2
  exit 1
fi

if [ "$ARGV_PLATFORM" = "electron" ]; then
  VERSION="$(jq -r '.devDependencies.electron' "$ARGV_BASE_DIRECTORY/package.json")"
elif [ "$ARGV_PLATFORM" = "node" ]; then
  VERSION="$("$HERE/resinci-read.sh" -b "$ARGV_BASE_DIRECTORY" -p node -l "$ARGV_PIPELINE")"
else
  echo "Unsupported platform: $ARGV_PLATFORM" 1>&2
  exit 1
fi

if [ "$VERSION" = "null" ]; then
  echo "Couldn't find a suitable npm target version" 1>&2
  exit 1
fi

echo "$VERSION"
