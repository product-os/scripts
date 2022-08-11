#!/bin/bash

###
# Copyright 2018 resin.io
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

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -r <architecture>" 1>&2
  echo "    -s <target operating system>" 1>&2
  echo "    -v <version type (production|prerelease|snapshot)>" 1>&2
  echo "    -n <npm data directory>" 1>&2
  echo "    -w <temporary directory>" 1>&2
  echo "    -a <amazon aws bucket>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_ARCHITECTURE=""
ARGV_TARGET_OPERATING_SYSTEM=""
ARGV_VERSION_TYPE=""
ARGV_NPM_DATA_DIRECTORY=""
ARGV_TEMPORARY_DIRECTORY=""
ARGV_S3_BUCKET=""

while getopts ":b:r:s:v:n:w:a:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    r) ARGV_ARCHITECTURE=$OPTARG ;;
    s) ARGV_TARGET_OPERATING_SYSTEM=$OPTARG ;;
    v) ARGV_VERSION_TYPE=$OPTARG ;;
    n) ARGV_NPM_DATA_DIRECTORY=$OPTARG ;;
    w) ARGV_TEMPORARY_DIRECTORY=$OPTARG ;;
    a) ARGV_S3_BUCKET=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_ARCHITECTURE" ] \
  || [ -z "$ARGV_TARGET_OPERATING_SYSTEM" ] \
  || [ -z "$ARGV_VERSION_TYPE" ] \
  || [ -z "$ARGV_NPM_DATA_DIRECTORY" ] \
  || [ -z "$ARGV_TEMPORARY_DIRECTORY" ] \
  || [ -z "$ARGV_S3_BUCKET" ]
then
  usage
fi

"$HERE/../shared/npm-execute-script.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -s concourse-build-node-cli \
  -o
