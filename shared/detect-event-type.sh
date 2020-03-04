#!/bin/bash

#  Event Types:
#   - BuildEvent
#   - MergeEvent
#   - VerisonEvent
#   - RebaseEvent
#
# The event type is detected based on the action and type of the github-events-resource event
# These represent the events and types of the events emitted by the github API which are then
# mapped to the event types above

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY" > /dev/null

action="$(jq -r '.action' .git/.version)"
type="$(jq -r '.type' .git/.version)"

emit_build_event() {
  echo "BuildEvent"
}

emit_merge_event() {
  echo "MergeEvent"
}

emit_version_event() {
  echo "VersionEvent"
}

emit_rebase_event() {
  echo "RebaseEvent"
}

if [ "$type" == "PullRequestEvent" ]; then
  if [ "${action}" == "merged" ]; then
    emit_merge_event
  else
    emit_build_event
  fi

elif [ "$type" == "IssueCommentEvent" ]; then
  if [ "$action" == "retest" ]; then
    emit_build_event
  elif [ "$action" == "rebase" ]; then
    emit_rebase_event
  fi

elif [ "$type" == "PushEvent" ]; then
  emit_build_event

elif [ "$type" == "VersionEvent" ]; then
  emit_version_event
fi
