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

"$HERE/../shared/check-dependency.sh" jq
"$HERE/../shared/check-dependency.sh" pkg

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -r <architecture>" 1>&2
  echo "    -o <operating system>" 1>&2
  echo "    -p <pipeline name>" 1>&2
  echo "    -w <temporary directory>" 1>&2
  echo "    -n <npm data directory>" 1>&2
  echo "    -a <AWS bucket name>" 1>&2
  echo "    -v <release type>" 1>&2
  exit 1
}

ARGV_ARCHITECTURE=""
ARGV_AWS_BUCKET=""
ARGV_BASE_DIRECTORY=""
ARGV_NPM_DATA_DIRECTORY=""
ARGV_OPERATING_SYSTEM=""
ARGV_PIPELINE=""
ARGV_TEMPORARY_DIRECTORY=""
ARGV_VERSION_TYPE=""

while getopts ":a:b:r:o:p:w:n:v:" option; do
  case $option in
    a) ARGV_AWS_BUCKET=$OPTARG ;;
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    n) ARGV_NPM_DATA_DIRECTORY=$OPTARG ;;
    o) ARGV_OPERATING_SYSTEM=$OPTARG ;;
    p) ARGV_PIPELINE=$OPTARG ;;
    r) ARGV_ARCHITECTURE=$OPTARG ;;
    w) ARGV_TEMPORARY_DIRECTORY=$OPTARG ;;
    v) ARGV_VERSION_TYPE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_ARCHITECTURE" ] \
  || [ -z "$ARGV_OPERATING_SYSTEM" ] \
  || [ -z "$ARGV_PIPELINE" ] \
  || [ -z "$ARGV_TEMPORARY_DIRECTORY" ] \
  || [ -z "$ARGV_AWS_BUCKET" ] \
  || [ -z "$ARGV_VERSION_TYPE" ] \
  || [ -z "$ARGV_NPM_DATA_DIRECTORY" ]; then
  usage
fi

PLATFORM_PKG="$("$HERE/../shared/platform-convert.sh" \
  -r "$ARGV_OPERATING_SYSTEM" \
  -t pkg)"

ENTRYPOINT="$("$HERE/../shared/resinci-read.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -p main \
  -l "$ARGV_PIPELINE")"

# Fallback to package.json
if [ -z "$ENTRYPOINT" ]; then
  ENTRYPOINT="$(jq -r '.main' "$ARGV_BASE_DIRECTORY/package.json")"
fi

if [ "$ENTRYPOINT" = "null" ]; then
  echo "Couldn't find entrypoint" 1>&2
  exit 1
fi

NAME="$(jq -r '.name' "$ARGV_BASE_DIRECTORY/package.json")"
VERSION="$("$HERE/../shared/get-deploy-version.sh" -b "$ARGV_BASE_DIRECTORY" -v "$ARGV_VERSION_TYPE")"

# We need to manually add the extension
BINARY="$NAME"
if [ "$ARGV_OPERATING_SYSTEM" = "windows" ]; then
  BINARY="$BINARY.exe"
fi

NODE_VERSION="$("$HERE/../shared/resinci-read.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -p node \
  -l "$ARGV_PIPELINE")"

if [ -z "$NODE_VERSION" ]; then
  echo "Couldn't determine target version" 1>&2
  exit 1
fi

PKG_VERSION="$(echo "$NODE_VERSION" | cut -d '.' -f 1)"
PKG_TARGET="node$PKG_VERSION-$PLATFORM_PKG-$ARGV_ARCHITECTURE"

DIST_DIRECTORY="$ARGV_BASE_DIRECTORY/dist"

# Don't add an extra -cli suffix if the
# application name already has it.
if [[ "$NAME" == *-cli ]]; then
  OUTPUT_FILE="$NAME"
else
  OUTPUT_FILE="$NAME-cli"
fi

OUTPUT_FILE="$OUTPUT_FILE-$VERSION-$ARGV_OPERATING_SYSTEM-$ARGV_ARCHITECTURE"

TEMPORARY_DIRECTORY_APP="$ARGV_TEMPORARY_DIRECTORY/$OUTPUT_FILE-app"
TEMPORARY_DIRECTORY_DIST="$ARGV_TEMPORARY_DIRECTORY/$OUTPUT_FILE-dist"
mkdir -p "$TEMPORARY_DIRECTORY_APP" "$TEMPORARY_DIRECTORY_DIST"

"$HERE/../shared/npm-install.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -r "$ARGV_ARCHITECTURE" \
  -t node \
  -s "$ARGV_OPERATING_SYSTEM" \
  -n "$ARGV_NPM_DATA_DIRECTORY" \
  -l "$ARGV_PIPELINE" \
  -x "$TEMPORARY_DIRECTORY_APP" \
  -a "${ARGV_AWS_BUCKET}" \
  -p

"$HERE/../shared/apply-patches.sh" \
  -b "$ARGV_BASE_DIRECTORY" \
  -d "$TEMPORARY_DIRECTORY_APP"

cp -r "$ARGV_BASE_DIRECTORY/lib" "$TEMPORARY_DIRECTORY_APP"

if [ -d "$ARGV_BASE_DIRECTORY/build" ]; then
  cp -r "$ARGV_BASE_DIRECTORY/build" "$TEMPORARY_DIRECTORY_APP"
fi

cp "$ARGV_BASE_DIRECTORY/package.json" "$TEMPORARY_DIRECTORY_APP"

pushd "$TEMPORARY_DIRECTORY_APP"
echo "Building target $PKG_TARGET"
echo "pkg $(pkg -v)"
pkg \
  --output "../$(basename "$TEMPORARY_DIRECTORY_DIST")/$BINARY" \
  --targets "$PKG_TARGET" \
  "$ENTRYPOINT"
popd

set +o nounset
if [ -n "$CSC_LINK" ] && [ -n "$CSC_KEY_PASSWORD" ]; then
  set -ex
  ls -lah
  pwd
  echo $TEMPORARY_DIRECTORY_DIST
  echo $TEMPORARY_DIRECTORY_APP

  OS="$(uname -o 2>/dev/null || true)"
  if [[ "$OS" == "Msys" ]]; then
    "$HERE/../shared/sign-exe.sh" \
      -f "$TEMPORARY_DIRECTORY_DIST/$BINARY" \
      -d "$NAME - $VERSION"
  fi
fi
set -o nounset

# Extract Node.js add-ons
rsync \
  --archive \
  --prune-empty-dirs \
  --progress \
  --include='*.node' \
  --include='*.dll' \
  --include='*/' \
  --exclude='*' \
  "$TEMPORARY_DIRECTORY_APP/node_modules" "$TEMPORARY_DIRECTORY_DIST"

mkdir -p "$DIST_DIRECTORY"

OUTPUT_PATH=""
FILENAME=""

if [ "$ARGV_OPERATING_SYSTEM" = "windows" ]; then
  FILENAME="${OUTPUT_FILE}.zip"
  OUTPUT_PATH="$DIST_DIRECTORY/${FILENAME}"

  "$HERE/../shared/zip-file.sh" \
    -f "$TEMPORARY_DIRECTORY_DIST" \
    -s "$ARGV_OPERATING_SYSTEM" \
    -o "${OUTPUT_PATH}"
else
  FILENAME="${OUTPUT_FILE}.tar.gz"
  OUTPUT_PATH="$DIST_DIRECTORY/${FILENAME}"

  "$HERE/../shared/tar-gz-file.sh" \
    -f "$TEMPORARY_DIRECTORY_DIST" \
    -o "${OUTPUT_PATH}"
fi
