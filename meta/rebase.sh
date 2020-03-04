#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
REBASE_TYPE="$2"
set -u

pushd $ARGV_DIRECTORY

if [ -f repo.yml ]; then
	should_rebase=$(yq read repo.yml 'autoRebase')

	if [ "$should_rebase" == "false" ]; then
		echo "Opting out of auto rebase"
		exit 0
	fi
fi

COMMITTER_NAME="Balena CI"
baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)

# Find PR to rebase
if [ "${REBASE_TYPE}" == "candidate" ]; then
	pr=$(find-commits candidate --repo ${baseRepo} --owner ${baseOrg})
	echo $pr
	CANDIDATE_BASE_BRANCH=$(echo $pr | jq -r .data.base.ref)
	CANDIDATE_HEAD_BRANCH=$(echo $pr | jq -r .data.head.ref)
elif [ "${REBASE_TYPE}" == "branch" ]; then
	CANDIDATE_BASE_BRANCH=$(jq -r '.base_branch' .git/.version)
	CANDIDATE_HEAD_BRANCH=$(jq -r '.head_branch' .git/.version)
else
	exit 1
fi

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$baseOrg/$baseRepo.git
git config --global user.name "$COMMITTER_NAME"
git config --global user.email "versionbot@balena.io"
set -o xtrace

# make sure branches are up-to-date
git fetch origin $CANDIDATE_BASE_BRANCH
git fetch origin $CANDIDATE_HEAD_BRANCH

# do the rebase
git checkout -B $CANDIDATE_HEAD_BRANCH origin/$CANDIDATE_HEAD_BRANCH
git rebase origin/$CANDIDATE_BASE_BRANCH

# push back
git push --force-with-lease
