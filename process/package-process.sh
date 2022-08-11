#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

# pushd rfq
# npm install
# npm link --force
# popd

# pushd $ARGV_DIRECTORY

# prNumber=$(jq -r '.number' .git/.version)
# commitID=$(jq -r '.sha' .git/.version)

# rfq generate . -o ../outputs -r ${prNumber} -c ${commitID}
# Need similar functionality in contract to yaml tool

cd $ARGV_DIRECTORY
ARG_EXT="mermaid"
#check if we have files of ARG type
count=0
for file in ./*; do
    if [[ $file == *.${ARG_EXT} ]]; then
	echo $file
	let count=$count+1
    fi
done

echo "Found "$count" mermaid files"

if [ $count == 0 ] ; then
    echo "Failed to find file with .${ARG_EXT} extension"
    exit 1
fi
exit 0
