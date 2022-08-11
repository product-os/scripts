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
  echo "    -m <npm version>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_NPM_VERSION=""

while getopts ":b:m:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    m) ARGV_NPM_VERSION=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] || [ -z "$ARGV_NPM_VERSION" ]
then
  usage
fi

"$HERE/../shared/npm-execute-script.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -s concourse-test-node-cli
