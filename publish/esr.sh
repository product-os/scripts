#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

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

owner=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
branch=$(jq -r '.base_branch' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)

popd
pushd resinci-deploy > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

resinci-deploy publish github \
  -v v${version} \
  -o ${owner} \
  -r ${repo} \
  -b ${buildBranch} \
  -t ${branch}

resinci-deploy clean github ${buildBranch} \
  -o ${owner} \
  -r ${repo}
