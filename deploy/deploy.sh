#!/bin/bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

# hard stop if disabled
if [[ -f "$(pwd)/.resinci.yml" ]]; then
    disabled="$(cat < "$(pwd)/.resinci.yml" | yq e - -j | jq -r .disabled)"
    if [[ -n $disabled ]] && [[ $disabled =~ true|True|1|Yes|yes|On|on ]]; then
        echo "task|step disabled=${disabled} in .resinci.yml" >&2
        exit 1
    fi
fi

# hard stop if Flowzone is enabled
if grep -Eqr '\s+uses:\sproduct-os\/flowzone\/\.github\/workflows\/.*' "$(pwd)/.github/workflows/"; then
    echo "Flowzone already enabled, disabling resinCI" >&2
    echo "see, https://github.com/product-os/flowzone" >&2
    exit 1
fi

taggedVersion=$(git log -1 --pretty=%B)
version=${taggedVersion:1}

[[ -f repo.yml ]] || exit 1

[[ "$(yq e '.type' repo.yml)" == "product" ]] || exit 1

keyframe=$(find .versionbot/contracts -type f -name ${version}.*)
if [ "$keyframe" == "" ]; then
  echo "No keyframe matching published version"
  exit 1
fi

# patch /etc/hosts for tunneling k8s api
echo "127.0.0.1 $K8S_STG_API" >> /etc/hosts
echo "hosts: files dns" > /etc/nsswitch.conf

# Install kubectl
wget -O kubectl "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && mv kubectl /usr/local/bin/

# Generate environments.yml
cp ./environments.tpl.yml ./environments.yml
sed -i "s/K8S_STG_BASTION_USERNAME/$K8S_STG_BASTION_USERNAME/g" ./environments.yml
sed -i "s/K8S_STG_BASTION/$K8S_STG_BASTION/g" ./environments.yml
sed -i "s/K8S_STG_API/$K8S_STG_API/g" ./environments.yml

# Get environments.yml required files (kubeconfig, jellyfish_key)
echo "$JELLYFISH_STG_KUBECONFIG" | base64 -d > ./kubeconfig
echo "$K8S_STG_BASTION_KEY" | base64 -d > jellyfish_pk
chmod 400 jellyfish_pk

popd
pushd katapult > /dev/null

npm install > /dev/null 2>&1
npm link > /dev/null 2>&1

popd > /dev/null
pushd $ARGV_DIRECTORY

echo "Should deploy"
cat $keyframe
echo "Skipping deploy"
# Deploy with katapult
# katapult deploy -t kubernetes -e staging -c . -v -k "$keyframe"
