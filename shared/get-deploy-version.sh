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
"$HERE/check-dependency.sh" git

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -v <version type (production|prerelease|snapshot)>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_VERSION_TYPE=""

while getopts ":b:v:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    v) ARGV_VERSION_TYPE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] || [ -z "$ARGV_VERSION_TYPE" ]; then
  usage
fi

PACKAGE_JSON="$ARGV_BASE_DIRECTORY/package.json"

# Append a short commit hash if building a snapshot version
APPLICATION_VERSION="$(jq -r '.version' "$PACKAGE_JSON")"
if [ "$ARGV_VERSION_TYPE" != "prerelease" ]; then
  APPLICATION_VERSION="$APPLICATION_VERSION+$(git --git-dir="$ARGV_BASE_DIRECTORY/.git" log -1 --format="%h")"
fi

echo "$APPLICATION_VERSION"
