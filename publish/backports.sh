#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

[[ -f repo.yml ]] || exit 0
backports=$(yq e '.backports' repo.yml)

if [ "${backports}" == "null" ]; then
  echo "No backports defined"
  exit 0
fi

base_org=$(jq -r '.base_org' .git/.version)
base_repo=$(jq -r '.base_repo' .git/.version)
base_branch=$(jq -r '.base_branch' .git/.version)
number=$(jq -r '.number' .git/.version)

commits=$(find-commits parsed -r ${base_repo} -o ${base_org} -n ${number})

backport_lines=$(echo ${commits} | jq -c '[.[].footers] | add' | jq 'map(select(. | startswith("Backport-to:")) | sub("Backport-to:";"") | sub("[[:space:]]";"")) | join(",")' | xargs)

new_commits="$(find-commits sha -r ${base_repo} -o ${base_org} -n ${number})"
first=$(echo "${new_commits}" | head -n1 | xargs)
last=$(echo "${new_commits}" | tail -n1  | xargs)
range="${first}^...${last}"

# setup github user to push backports
COMMITTER_NAME="Balena CI"
git remote set-url origin "https://x-access-token:$GITHUB_TOKEN@github.com/${base_org}/${base_repo}.git"
git config --global user.name "$COMMITTER_NAME"
git config --global user.email "versionbot@balena.io"
set -o xtrace

# Save current changes in stash
git stash

for backport_line in ${backport_lines//,/ }
do
  echo "target=${backport_line}"
  backport_branch="$(yq e ".backports.${backport_line}" repo.yml)"
  if [ "$backport_branch" == "null" ]; then
    continue
  fi
  echo "branch=${backport_branch}"
  git checkout "${backport_branch}"
  git checkout -B "${backport_branch}-backport-pr-${number}"
  git cherry-pick --allow-empty "${range}"
  hub pull-request --no-edit -p -b "${backport_branch}"
  git checkout "${base_branch}"
done

git stash pop
