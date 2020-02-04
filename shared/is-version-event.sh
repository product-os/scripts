#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

type="$(jq -r '.type' .git/.version)"

[[ "$type" == "VersionEvent" ]]
