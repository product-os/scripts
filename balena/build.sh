#!/usr/bin/env bash

echo "TASKINFO: Build the application in BalenaCloud"
set -e
SRC_PATH="$1"

# hard stop if disabled
if [[ -f "${SRC_PATH}/.resinci.yml" ]]; then
    disabled="$(cat < "${SRC_PATH}/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml"
        exit 1
    fi
fi

# https://git-secret.io/
if [[ -n ${GPG_PRIVATE_KEY} ]] && [[ -n ${GPG_PASSPHRASE} ]] \
  && which gpg2 && git secret --version; then
    tmpkey="$(mktemp)" \
      && echo "${GPG_PRIVATE_KEY}" | base64 -d > "${tmpkey}" \
      && GPG_TTY="$(tty)" \
      && export GPG_TTY \
      && echo "${GPG_PASSPHRASE}" | gpg2 \
      --pinentry-mode "${SECRETS_PINENTRY}" \
      --passphrase-fd 0 \
      --import "${tmpkey}" \
      && rm -f "${tmpkey}" \
      && gpg2 --list-keys \
      && gpg2 --list-secret-keys \
      && pushd "${SRC_PATH}" \
      && git secret reveal -fp "${GPG_PASSPHRASE}" \
      && git secret list \
      && git secret whoknows \
      && popd
fi

# bomb on unbound variables from here onwards
set -u

# Login before setting -x to avoid printing the TOKEN
balena login -t "${API_KEY}"
echo "Logged in as $(balena whoami | grep USERNAME | cut -d ' ' -f2)"
test "${DEBUG}" == "false" || set -x

balena_app_exists() {
  balena apps | grep -qE "\s+$1\s+"
}

get_project_name_from_source() {
    git -C "${SRC_PATH}" remote -v | head -1 | sed 's|.*:\(.*\)\.git.*$|\1|g'
}

get_org_name() {
    get_project_name_from_source | awk -F'/' '{print $1}'
}

get_app_name() {
    get_project_name_from_source | awk -F'/' '{print $2}'
}

concurrent_app_creation_happened() {
    local app_creation_output="$1"
    echo "$app_creation_output" | grep -q "Unique constraint violated"
}

create_balena_app() {
  set +e

  local app_name=$1; shift
  local org_name=$1; shift
  local rtn=0

  # If we want to get both the output and return value of a command in a subshell, we cannot use 'local'
  # since $? will get its return value which always is... 0
  output="$(balena app create "${app_name}" \
    -o "${org_name}" \
    -t "${DEVICE_TYPE}")"

  rtn=$?

  if test $rtn == 1 && concurrent_app_creation_happened "${output}"; then
      rtn=0
  fi

  set -e
  return $rtn
}

app_name="$(get_app_name)"
org_name="$(get_org_name)"

if ! balena_app_exists "${org_name}/${app_name}"; then
    create_balena_app "${app_name}" "${org_name}"
fi

balena push "${org_name}/${app_name}" -s "${SRC_PATH}"
