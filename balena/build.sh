#!/bin/bash -e

test "${DEBUG}" == "false" || set -x

SRC_PATH="$1"

balena_app_exists() {
  return $(balena apps | grep -q "$1")
}

get_project_name_from_source() {
    echo "$(git -C $SRC_PATH remote -v | head -1 | sed 's|.*/\(.*\)\.git.*$|\1|g')"
}

get_device_type_from_project() {
    echo "$(grep ^deviceType ${SRC_PATH}/repo.yml | awk '{print $2}')"
}

app_name=$(get_project_name_from_source)
device_type=$(get_device_type_from_project)

test -z "$device_type" && echo "ERROR: Missing device type" && exit 1

balena login -t $API_KEY
if ! balena_app_exists "$app_name"; then
  balena app create $app_name -t $device_type
fi

balena push $app_name -s $SRC_PATH
