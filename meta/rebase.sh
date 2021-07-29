#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
REBASE_TYPE="$2"
set -u

rebase_branch() {
	local base_branch="$1"
	local head_branch="$2"

	# make sure branches are up-to-date
	git fetch origin $base_branch
	git fetch origin $head_branch

	# do the rebase
	git checkout -B $head_branch origin/$head_branch
	git rebase origin/$base_branch

	# push back
	git push --force-with-lease
}

pushd $ARGV_DIRECTORY

if [ -f repo.yml ]; then
	should_rebase=$(yq e '.autoRebase' repo.yml)

	if [ "$should_rebase" == "false" ]; then
		echo "Opting out of auto rebase"
		exit 0
	fi
fi

COMMITTER_NAME="Balena CI"
baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$baseOrg/$baseRepo.git
git config --global user.name "$COMMITTER_NAME"
git config --global user.email "versionbot@balena.io"
set -o xtrace

# Find PR to rebase
if [ "${REBASE_TYPE}" == "candidate" ]; then
	IFS=$'\n'
	for pr in $(find-commits candidate --repo ${baseRepo} --owner ${baseOrg} -s 3 | jq '.[] | ([.data.base.ref, .data.head.ref])' | jq @sh); do
		# Run the row through the shell interpreter to remove enclosing double-quotes
		args=$(echo $pr | xargs echo)
		# eval must be used to interpret the spaces in $args as separating arguments
		eval rebase_branch $args
	done
	unset IFS
elif [ "${REBASE_TYPE}" == "branch" ]; then
	CANDIDATE_BASE_BRANCH=$(jq -r '.base_branch' .git/.version)
	CANDIDATE_HEAD_BRANCH=$(jq -r '.head_branch' .git/.version)
	rebase_branch $CANDIDATE_BASE_BRANCH $CANDIDATE_HEAD_BRANCH
else
	exit 1
fi
