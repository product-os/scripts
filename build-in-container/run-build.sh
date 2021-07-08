#!/bin/bash

source /docker-lib.sh
start_docker

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $ARGV_DIRECTORY

./build-docker.sh

cp ./deploy/* ../artefacts || true
