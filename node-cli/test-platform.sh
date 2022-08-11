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
    exit $EXIT_CODE
  }

  trap cleanup EXIT
  export NODE_GYP_DIR="/c/Users/${user}/.node-gyp-$$"
fi

"$HERE/../shared/task-start.sh" \
  -b $(pwd)/versioned-source \
  -l node-cli

# Install dependencies
if [ "$ARGV_TARGET_OPERATING_SYSTEM" == "darwin" ]; then
  export NVM_DIR=/usr/local/nvm
  export NODE_VERSION=v10.16.0
  export npm_config_cache="$NVM_DIR/npm-cache"
  mkdir -p "$npm_config_cache"
  set +x
  . "$NVM_DIR/nvm.sh"
  nvm install $NODE_VERSION
  nvm use $NODE_VERSION
  set -x
  src=$(readlink versioned-source) # resolve 'versioned-source' if it is a symlink
  chown -R resin:staff "${src:-versioned-source}" /Users/resin/.balena
  chown -R resin:admin "$npm_config_cache"
fi

pushd versioned-source
print_status

run_as npx npm@6.9.0 install
run_as npm test
