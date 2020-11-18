#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

#install extract-rfq tool
pushd rfq
npm install
npm run-script build
npm link --force
popd

cd $ARGV_DIRECTORY

# export bill of materials
echo -e "exporting bill of materials"
mkdir rfq
/export.sh -c ../rfq/kicad/config/*.yaml -e src/*.sch -d rfq

echo -e "exporting rfq.yml"

rfq generate . -o rfq

echo -e "zipping..."
zip -r ../outputs/rfq.zip rfq