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

"$HERE/check-dependency.sh" signtool

function usage() {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -f <file (.exe)>" 1>&2
  echo "    -d <signature description>" 1>&2
  echo "" 1>&2
  echo "Environment Variables" 1>&2
  echo "" 1>&2
  echo "    CSC_LINK          base64 encoded certificate" 1>&2
  echo "    CSC_KEY_PASSWORD  certificate password" 1>&2
  echo "" 1>&2
  exit 1
}

ARGV_FILE=""
ARGV_SIGNATURE_DESCRIPTION=""

while getopts ":f:d:" option; do
  case $option in
    f) ARGV_FILE="$OPTARG" ;;
    d) ARGV_SIGNATURE_DESCRIPTION="$OPTARG" ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_FILE" ] || [ -z "$ARGV_SIGNATURE_DESCRIPTION" ]
then
  usage
fi

TIMESTAMP_SERVER=http://timestamp.comodoca.com
CERTIFICATE_FILE=certificate.p12

echo "$CSC_LINK" | base64 --decode > "$CERTIFICATE_FILE"

# Ensure we delete the certificate even if the signing fails
set +e
signtool sign \
  -t "$TIMESTAMP_SERVER" \
  -d "$ARGV_SIGNATURE_DESCRIPTION" \
  -f "$CERTIFICATE_FILE" \
  -p "$CSC_KEY_PASSWORD" \
  "$ARGV_FILE"
rm "$CERTIFICATE_FILE"
set -e

signtool verify -pa -v "$ARGV_FILE"
