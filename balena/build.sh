#!/bin/bash -e

echo "TASKINFO: Build the application in BalenaCloud"

test "${DEBUG}" == "false" || set -x

SRC_PATH="$1"

balena_app_exists() {
  return $(balena apps | grep -q "$1")
}

get_project_name_from_source() {
    echo "$(git -C $SRC_PATH remote -v | head -1 | sed 's|.*/\(.*\)\.git.*$|\1|g')"
}

app_name=$(get_project_name_from_source)

balena login -t $API_KEY
if ! balena_app_exists "$app_name"; then
  balena app create $app_name -t $DEVICE_TYPE
fi

balena push $app_name -s $SRC_PATH
