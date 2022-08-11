#!/bin/bash

###
# Copyright 2019 balena.io
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

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_TARGET_OPERATING_SYSTEM" ]
then
  usage
fi

run_as () {
  if [ "$ARGV_TARGET_OPERATING_SYSTEM" == "darwin" ]; then
    su resin -c "$*"
  else
    eval "$*"
  fi
}

print_status () {
  whoami && echo path="$PATH" && pwd && ls -la
  which node npm
  node --version
  npm --version
}

if [ "$ARGV_TARGET_OPERATING_SYSTEM" == "windows" ]; then
  # All the msys binaries are in /usr/bin; we add them to the path below

  user=$(/usr/bin/ls /c/Users | /usr/bin/grep -i admin)

  export PATH="/c/MinGW/msys/1.0/bin:/c/Python27/:/c/Python27/Scripts:/c/Windows/system32:/c/Windows:/c/Windows/System32/Wbem:/c/Windows/System32/WindowsPowerShell/v1.0/:/c/Users/${user}/bin:/c/ProgramData/chocolatey/bin:/c/Program Files/dotnet/:/c/Program Files/Git/cmd:/c/Program Files/Git/usr/bin:/c/Users/${user}/AppData/Local/Microsoft/WindowsApps:/c/Program Files/nodejs/:/c/Users/${user}/AppData/Roaming/npm:/c/tools/mingw64/bin"

  function cleanup {
    EXIT_CODE=$?
    [[ -d /c/Users/${user}/.node-gyp-$$ ]] && rm -rf /c/Users/${user}/.node-gyp-$$
    [[ -d $BUILD_TMP ]] && rm -rf $BUILD_TMP
    exit $EXIT_CODE
  }

  export BUILD_TMP=$(mktemp -d -p "/c")

  trap cleanup EXIT
  export NODE_GYP_DIR="/c/Users/${user}/.node-gyp-$$"
fi


# Install dependencies
if [ "$ARGV_TARGET_OPERATING_SYSTEM" == "darwin" ]; then
  export OSX_KEYCHAIN='/Users/resin/Library/Keychains/pkgbuild-keychain-db'
  export NVM_DIR=/usr/local/nvm
  export NODE_VERSION=v10.16.0
  export npm_config_cache="$NVM_DIR/npm-cache"
  set +x
  . "$NVM_DIR/nvm.sh"
  nvm use $NODE_VERSION
  set -x
  src=$(readlink versioned-source) # resolve 'versioned-source' if it is a symlink
  chown -R resin:staff "${src:-versioned-source}" /Users/resin/.pkg-cache /Users/resin/.balena
  chmod -R 775 /Users/resin/.pkg-cache
fi

pushd versioned-source
print_status

run_as npx npm@6.9.0 install
run_as npm run package

if [ "$ARGV_TARGET_OPERATING_SYSTEM" == "darwin" ]; then
nvm deactivate
print_status
fi

ASSET=$(find $(pwd)/dist -type f)

popd
pushd resinci-deploy

npm install --unsafe-perm > /dev/null
npm link > /dev/null

popd
pushd versioned-source

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

echo $headBranch
echo $org
echo $repo
echo $version

echo "Publishing asset"
echo $ASSET

resinci-deploy store github-release $ASSET \
  --branch=$headBranch \
  --owner=$org \
  --repo=$repo \
  --version=$version
