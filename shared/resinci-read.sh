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

set -ue

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/check-dependency.sh" jq
"$HERE/check-dependency.sh" yq

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -p <property path>" 1>&2
  echo "    -l <pipeline name>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_PROPERTY=""
ARGV_PIPELINE=""

while getopts ":b:p:l:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    p) ARGV_PROPERTY=$OPTARG ;;
    l) ARGV_PIPELINE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_PROPERTY" ] \
  || [ -z "$ARGV_PIPELINE" ]; then
  usage
fi

RESINCI_JSON=${ARGV_BASE_DIRECTORY}/.resinci.*

if [ ! -f ${RESINCI_JSON} ]; then
  echo "No .resinci.yml file found at ${RESINCI_JSON}" 1>&2
  exit
fi

VALUE="$(yq e -j ${RESINCI_JSON} | jq -r ".[\"${ARGV_PIPELINE}\"].${ARGV_PROPERTY}")"

if [ "$VALUE" = "null" ]; then
  VALUE=""
fi

echo "$VALUE"
