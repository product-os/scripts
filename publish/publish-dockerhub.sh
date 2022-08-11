#!/bin/bash

source /docker-lib.sh
start_docker

echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
unset DOCKER_USERNAME
unset DOCKER_PASSWORD

echo "TASKINFO: Will tag docker image with generated version"

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

HERE=$(pwd)

pushd $ARGV_DIRECTORY

version=$(jq -r '.componentVersion' .git/.version)
sha=$(jq -r '.parentSha' .git/.versionist)
branch=$(jq -r '.head_branch' .git/.version)
isDocker=$(jq -r '.languages.docker' .git/.versionist)

if [ "$isDocker" != true ]; then
  echo "Not a Docker project; not attempting to publish"
  exit 0
fi

builds=$(${HERE}/scripts/shared/resinci-read.sh \
  -b $(pwd) \
  -l docker \
  -p builds | jq -c '.[]')

function publish_to_dockerhub() {
  repo=$1; shift

  docker pull $repo:$sha
  docker tag $repo:$sha $repo:latest
  docker tag $repo:$sha $repo:v$version
  docker tag $repo:$sha $repo:$version
  docker tag $repo:$sha $repo:$branch
  docker push $repo:latest
  docker push $repo:v$version
  docker push $repo:$version
  docker push $repo:$branch
}

if [ -n "$builds" ]; then
  for build in ${builds}; do
    echo ${build}
    docker_repo=$((echo ${build} | jq -r '.docker_repo') || \
      (cat .git/.version | jq -r '.org + "/" + .repo'))
    dockerfile=$((echo ${build} | jq -r '.dockerfile') || echo Dockerfile)
    publish=$((echo ${build} | jq -r '.publish') || echo true)

    # next if publish is false
    [[ "${publish}" == "false" ]] && continue

    publish_to_dockerhub $docker_repo
  done
else
  if [ -f .resinci.yml ]; then
    publish=$(yq r .resinci.yml 'docker.publish')
  else
    publish=true
  fi

  [[ "${publish}" == "false" ]] && exit 0

  publish_to_dockerhub $git_repo
fi
