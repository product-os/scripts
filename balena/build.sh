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

concurrent_app_creation_happened() {
    local app_creation_output="$1"
    echo "$app_creation_output" | grep -q "Unique constraint violated"
}

create_balena_app() {
  set +e

  local app_name="$1"
  local rtn=0

  # If we want to get both the output and return value of a command in a subshell, we cannot use 'local'
  # since $? will get its return value which always is... 0
  output=$(balena app create "$app_name" -t $DEVICE_TYPE)
  rtn=$?

  if test $rtn  == 1 && concurrent_app_creation_happened "$output"; then
      rtn=0
  fi

  set -e
  return $rtn
}

app_name=$(get_project_name_from_source)

if ! balena_app_exists "$app_name"; then
    create_balena_app "$app_name"
fi

balena push $app_name -s $SRC_PATH
