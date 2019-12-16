#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

action="$(yq r .git/.version 'action')"
type="$(yq r .git/.version 'type')"

if [ "$type" == "PullRequestEvent" ]; then
  [[ "${action}" != "merged" ]] && exit 0
elif [ "$type" == "IssueCommentEvent" ] || [ "$type" == "PushEvent" ]; then
  exit 0
fi

exit 1
