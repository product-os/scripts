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
"$HERE/check-dependency.sh" npm

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -s <script name>" 1>&2
  echo "    [-o optional, don't fail if script doesn't exist]" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_SCRIPT_NAME=""
ARGV_OPTIONAL=false

while getopts ":b:s:o" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    s) ARGV_SCRIPT_NAME=$OPTARG ;;
    o) ARGV_OPTIONAL=true ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] || [ -z "$ARGV_SCRIPT_NAME" ]; then
  usage
fi

PACKAGE_JSON="$ARGV_BASE_DIRECTORY/package.json"

if [ ! -f "$PACKAGE_JSON" ]; then
  echo "No package.json found at $ARGV_BASE_DIRECTORY" 1>&2
  exit 1
fi

if [ "$(jq -r ".scripts[\"$ARGV_SCRIPT_NAME\"]" "$PACKAGE_JSON")" = "null" ]; then
  if [ "$ARGV_OPTIONAL" = "true" ]; then
    echo "Script $ARGV_SCRIPT_NAME not defined. Omitting..."
    exit 0
  else 
    echo "Script $ARGV_SCRIPT_NAME not defined"
    exit 1
  fi
fi

pushd "$ARGV_BASE_DIRECTORY"
npm run "$ARGV_SCRIPT_NAME"
popd
