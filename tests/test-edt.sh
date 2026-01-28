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
  echo "${prefix}edt:${EDT_VERSION}"
}

test_1cedtcli_is_running_version() {
  log_header "Test :: 1cedtcli is running"

  local expected actual tag
  expected="1C:EDT Интерфейс командной строки"
  tag="$(resolve_image_tag)"
  actual=$(docker run --rm "$tag" 1cedtcli --help 2>/dev/null | head -n1)

  if assert_eq "$actual" "$expected"; then
    log_success "1cedtcli is running test passed"
  else
    log_failure "1cedtcli is running test failed"
  fi
}

test_1cedtcli_sh_is_running_version() {
  log_header "Test :: 1cedtcli.sh is running"

  local expected actual tag
  expected="1C:EDT Интерфейс командной строки"
  tag="$(resolve_image_tag)"
  actual=$(docker run --rm "$tag" 1cedtcli.sh --help 2>/dev/null | head -n1)

  if assert_eq "$actual" "$expected"; then
    log_success "1cedtcli.sh is running test passed"
  else
    log_failure "1cedtcli.sh is running test failed"
  fi
}

test_1cedt_version() {
  log_header "Test :: 1cedt version matches EDT_VERSION"

  local major_version
  major_version=$(echo "$EDT_VERSION" | cut -d '.' -f 1)
  
  if [ "$major_version" -le 2025 ]; then
    log_success "Test :: Тест версии 1cedt пропущен для EDT $EDT_VERSION (требуется > 2025)"
    return 0
  fi

  local expected actual tag
  expected="${EDT_VERSION}"
  tag="$(resolve_image_tag)"
  actual=$(docker run --rm "$tag" 1cedtcli -command version 2>/dev/null | tail -n1 | cut -d '.' -f 1-3)

  if assert_eq "$actual" "$expected"; then
    log_success "1cedt version test passed (expected: $expected, actual: $actual)"
  else
    log_failure "1cedt version test failed (expected: $expected, actual: $actual)"
  fi
}

# test calls
test_1cedtcli_is_running_version
test_1cedtcli_sh_is_running_version
test_1cedt_version
