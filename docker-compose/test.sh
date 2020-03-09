#!/bin/bash

# start docker daemon
source /docker-lib.sh
start_docker

echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $ARGV_DIRECTORY

sut=$(yq read repo.yml 'sut')

if [ "${sut}" == "" ]; then
  sut="sut"
fi

docker-compose -f docker-compose.yml -f docker-compose.test.yml up --exit-code-from "${sut}" --build
