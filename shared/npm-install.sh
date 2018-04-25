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

set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/check-dependency.sh" npm
"$HERE/check-dependency.sh" curl
"$HERE/check-dependency.sh" tar
"$HERE/check-dependency.sh" awk

SHA256SUM=$("$HERE/check-dependency.sh" sha256sum "shasum -a 256")

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -r <architecture>" 1>&2
  echo "    -t <target platform (node|electron)>" 1>&2
  echo "    -s <target operating system>" 1>&2
  echo "    -n <npm data directory>" 1>&2
  echo "    -l <pipeline name>" 1>&2
  echo "    -a <amazon aws bucket>" 1>&2
  echo "    [-x <install prefix>]" 1>&2
  echo "    [-p production install]" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_ARCHITECTURE=""
ARGV_TARGET_PLATFORM=""
ARGV_TARGET_OPERATING_SYSTEM=""
ARGV_NPM_DATA_DIRECTORY=""
ARGV_PIPELINE=""
ARGV_S3_BUCKET=""
ARGV_PREFIX=""
ARGV_PRODUCTION=false

while getopts ":b:r:t:s:n:l:a:x:p" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    r) ARGV_ARCHITECTURE=$OPTARG ;;
    t) ARGV_TARGET_PLATFORM=$OPTARG ;;
    s) ARGV_TARGET_OPERATING_SYSTEM=$OPTARG ;;
    n) ARGV_NPM_DATA_DIRECTORY=$OPTARG ;;
    l) ARGV_PIPELINE=$OPTARG ;;
    a) ARGV_S3_BUCKET=$OPTARG ;;
    x) ARGV_PREFIX=$OPTARG ;;
    p) ARGV_PRODUCTION=true ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_ARCHITECTURE" ] \
  || [ -z "$ARGV_TARGET_PLATFORM" ] \
  || [ -z "$ARGV_TARGET_OPERATING_SYSTEM" ] \
  || [ -z "$ARGV_NPM_DATA_DIRECTORY" ] \
  || [ -z "$ARGV_PIPELINE" ]
then
  usage
fi

RESINCI_CACHE_DIRECTORY="$ARGV_NPM_DATA_DIRECTORY/_resinci"
mkdir -p "$RESINCI_CACHE_DIRECTORY"

# Setup scoped npm prefix and cache directories
export npm_config_prefix="$ARGV_NPM_DATA_DIRECTORY/npm"
export npm_config_cache="$ARGV_NPM_DATA_DIRECTORY/npm-cache"
export npm_config_tmp="$ARGV_NPM_DATA_DIRECTORY/temp"
mkdir -p "$npm_config_prefix"
mkdir -p "$npm_config_cache"
mkdir -p "$npm_config_tmp"

# Proper log level
export npm_config_loglevel=warn

# Don't show spinner/progress bars
export npm_config_progress=false
export npm_config_spin=false

if [ "$ARGV_TARGET_OPERATING_SYSTEM" = "windows" ]; then
  MSVS_VERSION=2015
  export GYP_MSVS_VERSION="$MSVS_VERSION"
  export npm_config_msvs_version="$MSVS_VERSION"
fi

if [ "$ARGV_TARGET_PLATFORM" = "electron" ]; then

  # Ensure native addons are compiled with the correct headers
  # See https://github.com/electron/electron/blob/master/docs/tutorial/using-native-node-modules.md
  export npm_config_disturl=https://atom.io/download/electron
  export npm_config_runtime=electron

fi

npm_config_target="$("$HERE/npm-target-version.sh" \
  -p "$ARGV_TARGET_PLATFORM" \
  -b "$ARGV_BASE_DIRECTORY" \
  -l "$ARGV_PIPELINE")"
export npm_config_target
export npm_config_build_from_source=true

# Fixes npm stuck at "cloneCurrentTree: verb correctMkdir /root/.npm correctMk"
# See https://github.com/npm/npm/issues/7862#issuecomment-312107021
export npm_config_registry=http://registry.npmjs.org
export npm_config_strict_ssl=false

ELECTRON_ARCHITECTURE="$("$HERE/architecture-convert.sh" -r "$ARGV_ARCHITECTURE" -t node)"
export npm_config_arch="$ELECTRON_ARCHITECTURE"

if [ "$ARGV_PRODUCTION" == "true" ]; then
  export npm_config_production=true
fi

# From https://github.com/felixge/node-retry#retrytimeoutsoptions

# How many time to retry
export npm_config_fetch_retries=20

# The exponential factor to use
export npm_config_fetch_retry_factor=1.5

# The maximum amount of time between two retries
export npm_config_fetch_retry_maxtimeout=10000

# The amount of time before starting the first retry
export npm_config_fetch_retry_mintimeout=1000

cd "$ARGV_BASE_DIRECTORY"

echo "node: $(node -v)"
echo "npm: $(npm -v)"

echo "NPM configuration"
npm config list -l

function hash() {
  $SHA256SUM "$1" | cut -d ' ' -f1
}

# If there is a shrinkwrap file, then that's a much better source of truth
if [ -f ./npm-shrinkwrap.json ]; then
  CHECKSUM="$(hash ./npm-shrinkwrap.json)"
else
  CHECKSUM="$(hash ./package.json)"
fi

CACHE_KEY="$ARGV_TARGET_OPERATING_SYSTEM-$ARGV_TARGET_PLATFORM-$npm_config_target-$ARGV_ARCHITECTURE-$CHECKSUM.tar.gz"
S3_KEY="resinci/node_modules/$CACHE_KEY"
S3_URL="https://$ARGV_S3_BUCKET.s3.amazonaws.com/$S3_KEY"

function run_install() {
  UPLOAD_CACHE=false
  CACHE_STATUS_CODE="$(curl -k --silent --head --location "$S3_URL" | grep "^HTTP" | awk '{print $2}')"

  echo "Trying to find $CACHE_KEY..."

  if [ -z "$CACHE_STATUS_CODE" ]; then
    echo "No cache status code returned" 1>&2
    exit 1
  fi

  if [ -f "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY" ]; then
    echo "Reusing from $RESINCI_CACHE_DIRECTORY"
    tar fzx "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY"
  elif [ "$CACHE_STATUS_CODE" = "200" ]; then
    echo "Downloading from $S3_URL"
    curl -k --continue-at - --retry 100 --location --output "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY" "$S3_URL"
    echo "Decompressing $CACHE_KEY"
    tar fzx "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY"
  else
    UPLOAD_CACHE=true

    # When changing between target architectures, rebuild all dependencies,
    # since compiled add-ons will not work otherwise.
    echo "Rebuilding native modules"
    npm rebuild

    echo "Installing dependencies"
    npm install
  fi

  if [ "$ARGV_PRODUCTION" == "true" ]; then
    # Turns out that if `npm-shrinkwrap.json` contains development
    # dependencies then `npm install --production` will also install
    # those, despite knowing, based on `package.json`, that they are
    # really development dependencies. As a workaround, we manually
    # delete the development dependencies using `npm prune`.
    echo "Pruning development dependencies"
    PATH=$(pwd)/node_modules/.bin:$PATH npm prune --production
  else
    # Since we use an `npm-shrinkwrap.json` file, if you pull changes
    # that update a dependency and try to `npm install` directly, npm
    # will complain that your `node_modules` tree is not equal to what
    # is defined by the `npm-shrinkwrap.json` file, and will thus
    # refuse to do anything but install from scratch.
    echo "Pruning node_modules"
    PATH=$(pwd)/node_modules/.bin:$PATH npm prune
  fi

  if [ "$UPLOAD_CACHE" = "true" ]; then
    echo "Caching node_modules as $CACHE_KEY"
    tar czf "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY" ./node_modules

    if command -v aws 2>/dev/null 1>&2 && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
      echo "Uploading to S3 ($ARGV_S3_BUCKET)"
      aws s3api put-object \
        --bucket "$ARGV_S3_BUCKET" \
        --acl public-read \
        --key "$S3_KEY" \
        --body "$RESINCI_CACHE_DIRECTORY/$CACHE_KEY"
    fi
  fi
}

if [ -n "$ARGV_PREFIX" ]; then
  cp "$ARGV_BASE_DIRECTORY/package.json" "$ARGV_PREFIX/package.json"

  if [ -f "$ARGV_BASE_DIRECTORY/npm-shrinkwrap.json" ]; then
    cp "$ARGV_BASE_DIRECTORY/npm-shrinkwrap.json" "$ARGV_PREFIX/npm-shrinkwrap.json"
  fi

  if [ -f "$ARGV_BASE_DIRECTORY/binding.gyp" ]; then
    cp "$ARGV_BASE_DIRECTORY/binding.gyp" "$ARGV_PREFIX/binding.gyp"
  fi

  # Handle native code, if any
  if [ -d "$ARGV_BASE_DIRECTORY/src" ]; then
    cp -RLf "$ARGV_BASE_DIRECTORY/src" "$ARGV_PREFIX/src"
  fi

  pushd "$ARGV_PREFIX"
  run_install
  popd

  rm -f "$ARGV_PREFIX/package.json"
  rm -f "$ARGV_PREFIX/npm-shrinkwrap.json"
  rm -f "$ARGV_PREFIX/binding.gyp"
  rm -rf "$ARGV_PREFIX/src"
else
  run_install
fi
