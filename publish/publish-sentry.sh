#!/bin/bash

echo "TASKINFO: Will rename sentry project with final version"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE=$(pwd)

pushd $ARGV_DIRECTORY

[[ -f repo.yml ]] || exit 0

isSentry=$(yq read repo.yml 'sentry')

# If sentry is not set we exit without doing anything
[[ ${isSentry} != "null" ]] || exit 0

org=$(yq read repo.yml 'sentry.org')
team=$(yq read repo.yml 'sentry.team')

# If any of these vars are not defined in repo.yml we exit with error
[[ ${org} != "null" ]] && [[ ${team} != "null" ]] || exit 1

# These will always be defined
version=$(jq -r '.componentVersion' .git/.version)
buildBranch=$(jq -r '.buildBranch' .git/.versionist)
repo=$(jq -r '.base_repo' .git/.version)

popd

pushd resinci-deploy
npm install
npm link
popd

pushd $ARGV_DIRECTORY

resinci-deploy publish sentry \
  -o ${org} \
  -m ${team} \
  -n ${repo} \
  -b ${buildBranch} \
  -v v${version}
