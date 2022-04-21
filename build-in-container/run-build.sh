#!/usr/bin/env bash

##############################################################
#                                                            #
# !!! [ShellCheck](https://www.shellcheck.net/) YOUR WORK!!! #
#                                                            #
#                  (please and thank you)                    #
#                                                            #
##############################################################


docker_registry_mirror=${DOCKER_REGISTRY_MIRROR:-https://registry-cache-internal.balena-cloud.com}
export docker_registry_mirror

# shellcheck disable=SC1091
source /docker-lib.sh
start_docker 3 5 "" "${docker_registry_mirror}"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd "${ARGV_DIRECTORY}"

./build-docker.sh

cp ./deploy/* ../artefacts || true
