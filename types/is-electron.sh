#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f electron-builder.yml ] && exit 0

exit 1
