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
  echo "    -l <pipeline name>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_PIPELINE=""

while getopts ":b:l:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    l) ARGV_PIPELINE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] || [ -z "$ARGV_PIPELINE" ]; then
  usage
fi

if [ "$(uname)" = "Linux" ]; then
  if [ -n "$("$HERE/resinci-read.sh" -b "$ARGV_BASE_DIRECTORY" -p "dependencies.linux" -l "$ARGV_PIPELINE")" ]; then
    DEPENDENCIES="$("$HERE/resinci-read.sh" \
      -b "$ARGV_BASE_DIRECTORY" \
      -p "dependencies.linux | .[]" \
      -l "$ARGV_PIPELINE" | tr '\n' ' ')"
    echo "Installing Debian packages: $DEPENDENCIES"
    apt-get update
    # shellcheck disable=SC2086
    apt-get install -y --force-yes $DEPENDENCIES
  fi
fi
