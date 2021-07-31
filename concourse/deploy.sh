#!/bin/bash

ARGV_DIRECTORY="$1"
CONCOURSE_USERNAME="$2"
CONCOURSE_PASSWORD="$3"

pushd ${ARGV_DIRECTORY}

./bin/deploy-all-pipelines.sh -l github-events -u "$CONCOURSE_USERNAME" -w "$CONCOURSE_PASSWORD" -y

popd
