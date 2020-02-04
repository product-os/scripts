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
  echo "    -s <target operating system>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_TARGET_OPERATING_SYSTEM=""

while getopts ":b:s:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    s) ARGV_TARGET_OPERATING_SYSTEM=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] || [ -z "$ARGV_TARGET_OPERATING_SYSTEM" ]
then
  usage
fi

if [ "$ARGV_TARGET_OPERATING_SYSTEM" = "linux" ]; then
  # Electron test commands usually involve `electron-mocha` or
  # Spectron, which need to execute an actual Electron instance
  # to perform their job.
  # That won't run in a headless GNU/Linux worker unless we
  # run the command with `xvfb-run`.
  xvfb-run --server-args="-extension GLX" env ELECTRON_NO_ATTACH_CONSOLE=true "$HERE/../shared/npm-execute-script.sh" \
    -b "$ARGV_BASE_DIRECTORY" \
    -s concourse-test-electron
else
  env ELECTRON_NO_ATTACH_CONSOLE=true "$HERE/../shared/npm-execute-script.sh" \
    -b "$ARGV_BASE_DIRECTORY" \
    -s concourse-test-electron
fi
