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

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml" >&2
        exit 1
    fi
fi

# hard stop if Flowzone is enabled
if grep -Eqr '\s+uses:\sproduct-os\/flowzone\/\.github\/workflows\/.*' "$(pwd)/.github/workflows/"; then
    echo "Flowzone already enabled, disabling resinCI" >&2
    echo "see, https://github.com/product-os/flowzone" >&2
    exit 1
fi

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

emit_republish_event() {
  echo "RepublishEvent"
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
  elif [ "$action" == "republish" ]; then
    emit_republish_event
  fi

elif [ "$type" == "PushEvent" ]; then
  emit_build_event

elif [ "$type" == "VersionEvent" ]; then
  emit_version_event
fi
