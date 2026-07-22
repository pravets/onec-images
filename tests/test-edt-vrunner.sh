#!/bin/bash
set -euo pipefail

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  # .env may not exist locally; ignore if missing
  [ -f .env ] && source .env || true
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../tools/assert.sh"

TEST_FAILED=0

# Resolve image tag from env or defaults (matches build-edt-vrunner.sh scheme)
resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  if [[ -z "${EDT_VERSION:-}" ]]; then
    log_failure "EDT_VERSION не задан и IMAGE_TAG пуст — невозможно определить тег образа"
    exit 1
  fi
  echo "${prefix}edt-vrunner:${EDT_VERSION}${CI_SUFFIX:-}"
}

test_run_without_params() {
  log_header "Test :: vrunner run without params"

  local tag
  tag="$(resolve_image_tag)"

  # Run container and capture first lines of output to avoid hanging
  local out
  out=$(docker run --rm "$tag" 2>&1 | sed -n '1,20p' || true)

  # Basic checks — ensure binary identifies itself and prints commands list
  if ! assert_contain "$out" "Приложение: vrunner" "Ожидается сообщение о приложении"; then TEST_FAILED=1; return 1; fi

  log_success "vrunner run without params test passed"
}

test_help_shows_commands() {
  log_header "Test :: vrunner --help shows commands"

  local tag
  tag="$(resolve_image_tag)"

  local out
  out=$(docker run --rm "$tag" --help 2>&1 | sed -n '1,50p' || true)

  if ! assert_contain "$out" "Доступные команды:" "--help должен содержать раздел 'Доступные команды'"; then TEST_FAILED=1; return 1; fi
  if ! assert_contain "$out" "help, h" "--help должен перечислять help"; then TEST_FAILED=1; return 1; fi
  if ! assert_contain "$out" "cf" "--help должен перечислять cf"; then TEST_FAILED=1; return 1; fi

  log_success "vrunner --help test passed"
}

test_1cedtcli_is_available() {
  log_header "Test :: 1cedtcli is available in edt-vrunner image"

  local tag
  tag="$(resolve_image_tag)"

  local out
  out=$(docker run --rm --entrypoint 1cedtcli "$tag" --help 2>/dev/null | head -n1 || true)

  if ! assert_contain "$out" "1C:EDT Интерфейс командной строки" "Ожидается заголовок 1cedtcli"; then TEST_FAILED=1; return 1; fi

  log_success "1cedtcli availability test passed"
}

# Run tests
test_run_without_params || true
test_help_shows_commands || true
test_1cedtcli_is_available || true

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
