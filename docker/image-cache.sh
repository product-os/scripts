#!/usr/bin/env bash

sanitise_image_name() {
  echo "${1//[^a-zA-Z0-9_-]/-}"
}

export_image() {
  local image_name="$1"
  local path="$2"
  local sanitised_image_name
  sanitised_image_name=$(sanitise_image_name "${image_name}")
  docker save "${image_name}" > "${path}/${sanitised_image_name}"
}

import_image() {
  local image_name="$1"
  local path="$2"
  local sanitised_image_name
  sanitised_image_name=$(sanitise_image_name "${image_name}")
  docker load < "${path}/${sanitised_image_name}"
}

function image_variant() {
  local docker_image
  docker_image=$1
  local docker_tag
  docker_tag=${2:-default}

  if [[ "${docker_tag}" == 'default' ]]; then
    echo "${docker_image}"
    return
  fi

  image_variant="$(echo "${docker_image}" | awk -F':' '{print $2}')"
  docker_image="$(echo "${docker_image}" | awk -F':' '{print $1}')"

  if [[ "${image_variant}" == '' ]]; then
    echo "${docker_image}:${docker_tag}"
  else
    echo "${docker_image}:${image_variant}-${docker_tag}"
  fi
}
