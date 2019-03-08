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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$HERE/../shared/check-dependency.sh" jq
"$HERE/../shared/check-dependency.sh" node
"$HERE/../shared/check-dependency.sh" build

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -r <architecture>" 1>&2
  echo "    -t <package type (deb|rpm|appimage|portable|nsis|dmg|zip)>" 1>&2
  echo "    -v <version type (production|prerelease|snapshot)>" 1>&2
  echo "    -w <temporary directory>" 1>&2
  echo "    -n <npm data directory>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_ARCHITECTURE=""
ARGV_PACKAGE_TYPE=""
ARGV_VERSION_TYPE=""
ARGV_TEMPORARY_DIRECTORY=""
ARGV_NPM_DATA_DIRECTORY=""

while getopts ":b:r:t:v:w:n:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    r) ARGV_ARCHITECTURE=$OPTARG ;;
    t) ARGV_PACKAGE_TYPE=$OPTARG ;;
    v) ARGV_VERSION_TYPE=$OPTARG ;;
    w) ARGV_TEMPORARY_DIRECTORY=$OPTARG ;;
    n) ARGV_NPM_DATA_DIRECTORY=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_ARCHITECTURE" ] \
  || [ -z "$ARGV_PACKAGE_TYPE" ] \
  || [ -z "$ARGV_VERSION_TYPE" ] \
  || [ -z "$ARGV_TEMPORARY_DIRECTORY" ] \
  || [ -z "$ARGV_NPM_DATA_DIRECTORY" ]; then
  usage
fi

# Setup scoped npm prefix and cache directories
export npm_config_prefix="$ARGV_NPM_DATA_DIRECTORY/npm"
export npm_config_cache="$ARGV_NPM_DATA_DIRECTORY/npm-cache"
mkdir -p "$npm_config_prefix"
mkdir -p "$npm_config_cache"

if [ "$ARGV_PACKAGE_TYPE" = "rpm" ] \
  || [ "$ARGV_PACKAGE_TYPE" = "deb" ] \
  || [ "$ARGV_PACKAGE_TYPE" = "appimage" ]; then
  ELECTRON_BUILDER_OS="linux"
elif [ "$ARGV_PACKAGE_TYPE" = "portable" ] \
  || [ "$ARGV_PACKAGE_TYPE" = "nsis" ]; then
  ELECTRON_BUILDER_OS="win"
elif [ "$ARGV_PACKAGE_TYPE" = "dmg" ] \
  || [ "$ARGV_PACKAGE_TYPE" = "zip" ]; then
  ELECTRON_BUILDER_OS="mac"
else
  echo "Unknown package type: $ARGV_PACKAGE_TYPE" 1>&2
  exit 1
fi

APPLICATION_VERSION="$("$HERE/../shared/get-deploy-version.sh" -b "$ARGV_BASE_DIRECTORY" -v "$ARGV_VERSION_TYPE")"

# RPM and DEB packages can't handle hyphens in versions, which can
# be the case if you have something like 1.0.0-beta.18
if [ "$ARGV_PACKAGE_TYPE" = "rpm" ] || [ "$ARGV_PACKAGE_TYPE" = "deb" ]; then
  APPLICATION_VERSION="$(echo "$APPLICATION_VERSION" | tr "-" "~")"
fi

PACKAGE_JSON="$ARGV_BASE_DIRECTORY/package.json"

# Append `electron` to the application name on GNU/Linux
APPLICATION_NAME="$(jq -r '.name' "$PACKAGE_JSON")"
if [ "$ELECTRON_BUILDER_OS" = "linux" ]; then
  APPLICATION_NAME="$APPLICATION_NAME-electron"
fi

ELECTRON_BUILDER_ARCHITECTURE="$("$HERE/../shared/architecture-convert.sh" -r "$ARGV_ARCHITECTURE" -t electron-builder)"
ELECTRON_BUILDER_CONFIG="$(mktemp)"

node \
  "$HERE/extend-electron-builder-config.js" \
  "$ARGV_BASE_DIRECTORY/.resinci.json" \
  "$APPLICATION_NAME" \
  > "$ELECTRON_BUILDER_CONFIG"

# For debugging purposes
echo "Electron Builder Configuration:"
cat "$ELECTRON_BUILDER_CONFIG"

ELECTRON_BUILDER_OPTIONS=""
if [ -z ${ANALYTICS_SENTRY_TOKEN-} ]; then
  echo "WARNING: No Sentry token found (ANALYTICS_SENTRY_TOKEN is not set)" 1>&2
else
  echo "Found ANALYTICS_SENTRY_TOKEN"
  ELECTRON_BUILDER_OPTIONS+=" --extraMetadata.analytics.sentry.token=${ANALYTICS_SENTRY_TOKEN}"
fi

if [ -z ${ANALYTICS_MIXPANEL_TOKEN-} ]; then
  echo "WARNING: No Mixpanel token found (ANALYTICS_MIXPANEL_TOKEN is not set)" 1>&2
else
  echo "Found ANALYTICS_MIXPANEL_TOKEN"
  ELECTRON_BUILDER_OPTIONS+=" --extraMetadata.analytics.mixpanel.token=${ANALYTICS_MIXPANEL_TOKEN}"
fi

if [ "$ELECTRON_BUILDER_OS" = "win" ]; then
  # Export the path that's added by running
  # C:\Program Files (x86)\Microsoft Visual C++ Build Tools\vcbuildtools.bat
  # on the windows node. This should allow us to find signtool.exe
  # in /c/Program\ Files\ \(x86\)/Windows\ Kits/10/bin/x86
  NEW_PATH="/c/Program Files (x86)/MSBuild/14.0/bin"
  NEW_PATH+=":/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/BIN"
  NEW_PATH+=":/c/Windows/Microsoft.Net/Framework/v4.0.30319"
  NEW_PATH+=":/c/Windows/Microsoft.Net/Framework"
  NEW_PATH+=":/c/Program Files (x86)/Windows Kits/10/bin/x86"
  NEW_PATH+=":/c/Program Files (x86)/Microsoft SDKs/Windows/v10.0A/bin/NETFX 4.6.1 Tools"
  export PATH="$NEW_PATH:$PATH"
fi

if [ -z ${ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES-} ]; then
  ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES=${ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES-}
else
  ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES="true"
fi

# For now we build AppImages in a very custom way due to
# issues on the electron-builder project
if [ "$ARGV_PACKAGE_TYPE" = "appimage" ]; then
  pushd "$ARGV_BASE_DIRECTORY"
  ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES="$ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES" \
  TARGET_ARCH="$ARGV_ARCHITECTURE" \
    build --dir "--$ELECTRON_BUILDER_OS" "$ARGV_PACKAGE_TYPE" \
    ${ELECTRON_BUILDER_OPTIONS} \
    "--$ELECTRON_BUILDER_ARCHITECTURE" \
    --config="$ELECTRON_BUILDER_CONFIG" \
    --extraMetadata.name="$APPLICATION_NAME" \
    --extraMetadata.version="$APPLICATION_VERSION" \
    --extraMetadata.packageType="$ARGV_PACKAGE_TYPE"
  popd

  PRODUCT_NAME="$("$HERE/../shared/resinci-read.sh" \
    -b "$ARGV_BASE_DIRECTORY" \
    -p "builder.productName" \
    -l electron)"
  APPLICATION_DESCRIPTION="$(jq -r '.description' "$PACKAGE_JSON")"
  APPIMAGE_ARCHITECTURE="$("$HERE/../shared/architecture-convert.sh" -r "$ARGV_ARCHITECTURE" -t appimage)"
  ELECTRON_BUILDER_ARCHITECTURE="$("$HERE/../shared/architecture-convert.sh" -r "$ARGV_ARCHITECTURE" -t electron-builder)"
  BUILD_DIRECTORY="$ARGV_BASE_DIRECTORY/dist"

  APPDIR_PATH="$BUILD_DIRECTORY/$APPLICATION_NAME-$APPLICATION_VERSION-linux.AppDir"
  APPIMAGE_PATH="$BUILD_DIRECTORY/$APPLICATION_NAME-$APPLICATION_VERSION-$APPIMAGE_ARCHITECTURE.AppImage"
  APPIMAGE_ZIP_PATH="$BUILD_DIRECTORY/$APPLICATION_NAME-$APPLICATION_VERSION-linux-$ELECTRON_BUILDER_ARCHITECTURE.zip"

  if [ "$ARGV_ARCHITECTURE" = "x64" ]; then
    ELECTRON_BUILDER_LINUX_UNPACKED_DIRECTORY="linux-unpacked"
  else
    ELECTRON_BUILDER_LINUX_UNPACKED_DIRECTORY="linux-$ELECTRON_BUILDER_ARCHITECTURE-unpacked"
  fi

  "$HERE/electron-create-appdir.sh" \
    -n "$PRODUCT_NAME" \
    -d "$APPLICATION_DESCRIPTION" \
    -p "$BUILD_DIRECTORY/$ELECTRON_BUILDER_LINUX_UNPACKED_DIRECTORY" \
    -r "$ARGV_ARCHITECTURE" \
    -b "$APPLICATION_NAME" \
    -i "$ARGV_BASE_DIRECTORY/assets/icon.png" \
    -o "$APPDIR_PATH"

  "$HERE/electron-create-appimage.sh" \
    -d "$APPDIR_PATH" \
    -r "$ARGV_ARCHITECTURE" \
    -w "$ARGV_TEMPORARY_DIRECTORY" \
    -o "$APPIMAGE_PATH"

  "$HERE/../shared/zip-file.sh" \
    -f "$APPIMAGE_PATH" \
    -s linux \
    -o "$APPIMAGE_ZIP_PATH"
else
  pushd "$ARGV_BASE_DIRECTORY"
  ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES="$ELECTRON_BUILDER_ALLOW_UNRESOLVED_DEPENDENCIES" \
  TARGET_ARCH="$ARGV_ARCHITECTURE" \
    build "--$ELECTRON_BUILDER_OS" "$ARGV_PACKAGE_TYPE" ${ELECTRON_BUILDER_OPTIONS} \
    "--$ELECTRON_BUILDER_ARCHITECTURE" \
    --config="$ELECTRON_BUILDER_CONFIG" \
    --extraMetadata.name="$APPLICATION_NAME" \
    --extraMetadata.version="$APPLICATION_VERSION" \
    --extraMetadata.packageType="$ARGV_PACKAGE_TYPE"
  popd
fi

rm "$ELECTRON_BUILDER_CONFIG"

