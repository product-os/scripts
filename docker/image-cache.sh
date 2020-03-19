sanitise_image_name() {
  echo ${1//[^a-zA-Z0-9_-]/-}
}

export_image() {
  local image_name="$1"
  local path="$2"
  local sanitised_image_name=$(sanitise_image_name "${image_name}")
  docker save $image_name > "${path}/${sanitised_image_name}"
}

import_image() {
  local image_name="$1"
  local path="$2"
  local sanitised_image_name=$(sanitise_image_name "${image_name}")
  docker load < "${path}/${sanitised_image_name}"
}
