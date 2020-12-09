#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
ARG_EXT="$2"
set -u

# [[ "${DEBUG}" == "false" ]] || set -x

cd $ARGV_DIRECTORY

#check if we have files of ARG type
for file in src/*; do
    if [[ $file == *.${ARG_EXT} ]]; then
        exit 0
    fi
done

echo "Failed to find file with .${ARG_EXT} extension"
exit 1
