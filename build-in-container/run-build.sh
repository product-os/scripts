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

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml" >&2
        exit 1
    fi
fi

# hard stop if Flowzone is enabled
if grep -Eqr '\s+uses:\sproduct-os\/flowzone\/\.github\/workflows\/.*' "$(pwd)/.github/workflows/"; then
    echo "Flowzone already enabled, disabling resinCI" >&2
    echo "see, https://github.com/product-os/flowzone" >&2
    exit 1
fi

./build-docker.sh

cp ./deploy/* ../artefacts || true
