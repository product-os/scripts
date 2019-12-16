#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

action="$(jq -r '.action' .git/.version)"
type="$(jq -r '.type' .git/.version)"

if [ "$type" == "PullRequestEvent" ]; then
  [[ "${action}" != "merged" ]] && exit 0
elif [ "$type" == "IssueCommentEvent" ] || [ "$type" == "PushEvent" ]; then
  exit 0
fi

exit 1
