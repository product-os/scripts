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

if [ -d "$ARGV_BASE_DIRECTORY/node_modules/.bin" ] && \
   [ ! -f "$ARGV_BASE_DIRECTORY/node_modules/bin.tar.gz" ]; then
  # Concourse will `cp` inputs to any subsequent tasks. The
  # `node_modules/.bin` directory contains symlinks that get
  # resolved by a recursive copy operation meaning that they
  # will not work as expected. In order to workaround this, we
  # create a tarball out of the `.bin` directory (which will
  # preserve the file attributes) and store it inside the
  # output directory of this task.
  # Subsequent tasks will need to decompress this tarball
  # before running any command.
  echo "Packing node_modules bin directory"
  pushd "$ARGV_BASE_DIRECTORY"
  tar -czf ./node_modules/bin.tar.gz ./node_modules/.bin
  popd
fi
