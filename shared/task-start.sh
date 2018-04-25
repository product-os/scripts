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

set -ue

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Base dependencies
"$HERE/system-dependencies.sh" -b "$ARGV_BASE_DIRECTORY" -l "$ARGV_PIPELINE"
"$HERE/pip-dependencies.sh" -b "$ARGV_BASE_DIRECTORY"

if [ -f "$ARGV_BASE_DIRECTORY/node_modules/bin.tar.gz" ]; then
  echo "Unpacking node_modules bin directory"
  pushd "$ARGV_BASE_DIRECTORY"
  tar -xf ./node_modules/bin.tar.gz
  popd

  rm "$ARGV_BASE_DIRECTORY/node_modules/bin.tar.gz"
fi
