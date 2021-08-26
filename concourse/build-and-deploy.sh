#!/bin/bash

pushd $SOURCE_PATH

[[ -f repo.yml ]] || exit 0

repoType=$(yq e '.type' repo.yml)

[[ "${repoType}" == "concourse" ]] || exit 0

popd

echo "Building concourse"

./scripts/concourse/build.sh "$SOURCE_PATH"

echo "Deploying concourse"

./scripts/concourse/deploy.sh "$SOURCE_PATH" "$CONCOURSE_USERNAME" "$CONCOURSE_PASSWORD"
