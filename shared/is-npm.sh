#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

HERE=$(pwd)

pushd ${ARGV_DIRECTORY}

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

should_run="$(${HERE}/scripts/shared/resinci-read.sh \
  -b $(pwd) \
  -l npm \
  -p run)"

[[ "${should_run}" == "true" ]] && exit
[[ "${should_run}" == "false" ]] && exit 1
if [[ -f "repo.yml" ]]; then
  project_type="$(yq e '.type' repo.yml)"
  # If project type is node-cli we still might want to publish to npm
  [[ "$project_type" == "node-cli" ]] && exit 0
  # If project type is not node, exit 1
  [[ "$project_type" != "node" ]] && exit 1
fi
[[ -f package.json ]] || exit 1

# If we made it through the checks, exit successfully
exit 0
