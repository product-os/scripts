#!/bin/bash

set -e

ARGV_DIRECTORY="$1"

pushd "$ARGV_DIRECTORY"

type="$(yq r .git/.version 'type')"

[[ "$type" == "VersionEvent" ]]
