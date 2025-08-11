#!/bin/bash
set -e

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  source .env
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../tools/assert.sh"

resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  echo "${prefix}edtcli:${EDT_VERSION}"
}

# 1) 1cedtcli should run
log_header "Test :: edtcli image runs 1cedtcli"
expected="1C:EDT Интерфейс командной строки"
tag="$(resolve_image_tag)"
actual=$(docker run --rm "$tag" --help 2>/dev/null | head -n1)

if assert_contain "$actual" "$expected"; then
  log_success "edtcli image runs 1cedtcli test passed"
else
  log_failure "edtcli image runs 1cedtcli test failed"
fi
