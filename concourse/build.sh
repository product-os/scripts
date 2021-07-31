#!/bin/bash

ARGV_DIRECTORY="$1"

pushd ${ARGV_DIRECTORY}

# Install dependencies for build and deploy scripts
npm install
pip install -r requirements.txt

# HACK: Override fly version coming from the image with a newer one that works with our concourse config
wget -O /usr/local/bin/fly 'https://ci.balena-dev.com/api/v1/cli?arch=amd64&platform=linux' \
&& chmod +x /usr/local/bin/fly

./bin/build-all-pipelines.sh

popd
