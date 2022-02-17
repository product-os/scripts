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
  echo "    -r <architecture>" 1>&2
  exit 1
}

ARGV_BASE_DIRECTORY=""
ARGV_GO_PKG=""
ARGV_ARCHITECTURE=""

while getopts ":b:p:r:" option; do
  case $option in
    b) ARGV_BASE_DIRECTORY=$OPTARG ;;
    p) ARGV_GO_PKG=$OPTARG ;;
    r) ARGV_ARCHITECTURE=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$ARGV_BASE_DIRECTORY" ] \
  || [ -z "$ARGV_GO_PKG" ] \
  || [ -z "$ARGV_ARCHITECTURE" ]
then
  usage
fi

case $ARGV_ARCHITECTURE in
  amd64) ;; # noop
  *) echo "$ARGV_ARCHITECTURE unsupported" 1>&2; exit 1 ;;
esac

mkdir -p "/go/src/${ARGV_GO_PKG}"
cp -Lr "${ARGV_BASE_DIRECTORY}/." "/go/src/${ARGV_GO_PKG}/"
pushd "/go/src/${ARGV_GO_PKG}" >/dev/null

hack/make.sh dynbinary
