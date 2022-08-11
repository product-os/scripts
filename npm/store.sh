#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

emitPrivateArgs(){
  local args=""
  if test "$privateRepo" == "true"; then
    args="--private"
    test -n "$READONLY_TEAM" && args="$args -t $READONLY_TEAM"
  fi

  echo "$args"
}

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

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

privateRepo=true
if curl -s -o /dev/null -I -w "%{http_code}" https://github.com/$org/$repo -I | grep '200'; then
  privateRepo=false
fi

popd

pushd resinci-deploy
npm install
npm link
popd

pushd $ARGV_DIRECTORY

if egrep '(preversion|postversion|prepare|prepack|postpack|publish)' package.json; then
  set +x
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
  set -x
  npm install --unsafe-perm
fi

sha=$(git rev-parse HEAD)

npm config set unsafe-perm

privateArgs=$(emitPrivateArgs)
resinci-deploy store npm .  \
  $privateArgs              \
  -s ${sha}                 \
  -b ${headBranch}          \
  -v ${version}
