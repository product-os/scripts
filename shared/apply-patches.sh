#!/bin/bash

###
# Copyright 2016 resin.io
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

"$HERE/check-dependency.sh" patch

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    [-d <destination directory>]" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_DESTINATION_DIRECTORY=""

while getopts ":b:d:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    d) ARGV_DESTINATION_DIRECTORY=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ]; then
  usage
fi

# Default destination directory to base directory
if [ -z "$ARGV_DESTINATION_DIRECTORY" ]; then
  ARGV_DESTINATION_DIRECTORY="$ARGV_BASE_DIRECTORY"
fi

PATCHES_DIRECTORY="$ARGV_BASE_DIRECTORY/patches"

if [ -d "$PATCHES_DIRECTORY" ]; then
  for file in "$PATCHES_DIRECTORY"/*; do
    if [ ! -f "$file" ]; then
      echo "Ignoring $file, not a file"
    else
      echo "Applying $file to $ARGV_DESTINATION_DIRECTORY"
      patch \
        --silent \
        --force \
        --directory="$ARGV_DESTINATION_DIRECTORY" \
        --ignore-whitespace \
        --strip=1 \
        --input="$file" || echo "Ignoring $file, patch already applied"
    fi
  done
fi
