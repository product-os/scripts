#!/bin/bash

set -u
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage () {
  echo "Usage: $0" 1>&2
  echo "" 1>&2
  echo "Options" 1>&2
  echo "" 1>&2
  echo "    -b <base project directory>" 1>&2
  echo "    -p <go package>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_GO_PKG=""

while getopts ":b:p:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    p) ARGV_GO_PKG=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_GO_PKG" ]
then
  usage
fi

# concourse mounts the task context under /tmp/build, but the dind script
# mounts a tmpfs over it, which is required for running some unit tests
#
# move the source files to the GOPATH set up in the build image
# and change directory
mkdir -p "/go/src/${ARGV_GO_PKG}"
cp -Lr "${ARGV_BASE_DIRECTORY}/." "/go/src/${ARGV_GO_PKG}/"
pushd "/go/src/${ARGV_GO_PKG}" >/dev/null

hack/dind hack/test/unit
