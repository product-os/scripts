#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

headBranch=$(jq -r '.head_branch' .git/.version)
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
version=$(jq -r '.componentVersion' .git/.version)

popd

pushd resinci-deploy
npm install
npm link --force
popd

ASSETS=$(find "outputs/" -type f)

echo $ASSETS

# Example RELEASE_URL - 'https://github.com/balena-io-hardware/hardware-process-test/releases/tag/untagged-0b077a1f62efcb13db09'
output=$(resinci-deploy store github-release "${ASSETS}" \
  -b ${headBranch} \
  -r ${repo} \
  -o ${org} \
  -v ${version})

RELEASE_URL=$( grep -nri -A 10 'Published draft release:' <<< "$output" | grep html_url -A 1 | grep -e "[\'\"]" )

SUBJECT='{"ownerName":"'${org}'", "repoName":"'${repo}'", "branch":"'${headBranch}'", "installationId":15652884}'
BODY='Please use the release found at -'

curl -s --user "api:$MAILGUN_API_KEY" \
     https://api.mailgun.net/v3/"$MAILGUN_DOMAIN"/messages \
	 -F from="$MAILGUN_FROM"\
	 -F to="$MAILGUN_TO" \
	 -F subject="$SUBJECT" \
	 -F text="$BODY $RELEASE_URL"
