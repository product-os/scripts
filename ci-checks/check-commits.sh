#!/bin/bash

echo "TASKINFO: Check if all the commits in the PR adhere to the guidelines in resin-commit-lint"
set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

apk add --no-cache grep

author=$(cd ${ARGV_DIRECTORY} && git show -s --format=%aN)
if echo "$author" | egrep -zoi 'resin-io(-\w+)?-versionbot'; then
  echo "User is a versionbot; skipping validation"
  exit 0
fi

pushd ${ARGV_DIRECTORY} > /dev/null

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

> lint_report.txt
FAILED="false"
# File separator set to \n. N.B. This will be valid for the whole script
IFS=$'\n'

baseRepo=$(jq -r '.base_repo' .git/.version)
baseOrg=$(jq -r '.base_org' .git/.version)
number=$(jq -r '.number' .git/.version)

# Show all commits on the current branch that are not on master
for SHA in $(find-commits sha --owner=$baseOrg --repo=$baseRepo --number=$number); do
  # Show commit body
  body=$(git show $SHA -s --format=%B)

  echo "Validating commit: $SHA" >> lint_report.txt
  echo "" >> lint_report.txt
  echo $(git show $SHA -s --format=%s) >> lint_report.txt
  echo "" >> lint_report.txt

  # Interpret escaped quotes
  body="${body//\\\"/\"}"
  # Re-escape all quotes
  body="${body//\"/\\\"}"
  # Check if the commit is valid.
  if ! resin-commit-lint "${body}" >> lint_report.txt 2>&1 ; then
    FAILED="true"
  fi
  echo "" >> lint_report.txt
  echo "" >> lint_report.txt
done

[[ "${FAILED}" != "true" ]] && exit 0
cat lint_report.txt && exit 1
