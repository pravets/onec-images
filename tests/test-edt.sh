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

test_1cedtcli_is_running_version() {
  log_header "Test :: 1cedtcli is running"

  local expected actual
  expected="1C:EDT Интерфейс командной строки"
  actual=$(docker run --rm $DOCKER_REGISTRY_URL/edt:$EDT_VERSION 2>/dev/null | head -n1)

  if assert_contain "$actual" "$expected"; then
    log_success "1cedtcli is running test passed"
  else
    log_failure "1cedtcli is running test failed"
  fi
}

# test calls
test_1cedtcli_is_running_version
