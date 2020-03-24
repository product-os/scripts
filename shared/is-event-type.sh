#!/bin/bash

set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARGV_DIRECTORY="$1"
ARGV_EVENT="$2"


detected_type="$(${HERE}/detect-event-type.sh "${ARGV_DIRECTORY}")"

test "${detected_type}" == "$ARGV_EVENT"
