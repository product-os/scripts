#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

apk add --no-cache openssh > /dev/null

mkdir ~/.ssh
echo "$SSH_KEY" > ~/.ssh/id_rsa
chmod 0400 ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

unset SSH_KEY

pushd $ARGV_DIRECTORY

cat .git/.version
org=$(jq -r '.base_org' .git/.version)
repo=$(jq -r '.base_repo' .git/.version)
branch=$(jq -r '.base_branch' .git/.version)

popd
pushd repo-config

npm install
npm link

repo-config configure-repo \
  --org $org \
  --repo $repo

repo-config protect-branch \
  --org $org \
  --repo $repo \
  --branch $branch
