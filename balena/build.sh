#!/usr/bin/env bash

echo "TASKINFO: Build the application in BalenaCloud"
set -e
SRC_PATH="$1"
set -u

# Login before setting -x to avoid printing the TOKEN
balena login -t $API_KEY
echo "Logged in as $(balena whoami | grep USERNAME | cut -d ' ' -f2)"
test "${DEBUG}" == "false" || set -x

balena_app_exists() {
  return $(balena apps | grep -q "$1")
}

get_project_name_from_source() {
    echo "$(git -C $SRC_PATH remote -v | head -1 | sed 's|.*/\(.*\)\.git.*$|\1|g')"
}

app_name=$(get_project_name_from_source)

if ! balena_app_exists "$app_name"; then
  balena app create $app_name -t $DEVICE_TYPE
fi

balena push $app_name -s $SRC_PATH
