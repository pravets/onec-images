#!/bin/bash
# Проверка образа cs-site: статика отдаётся, config.json собирается из окружения.
set -euo pipefail

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  [ -f .env ] && source .env || true
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../tools/assert.sh"

TEST_FAILED=0
IMAGE="${CS_IMAGE:-cs-site}"
CS_VERSION="${CS_VERSION:-30.0.42}"
CONTAINER="cs-site-test-$$"
EXPECTED_URL="wss://cs.test.example"

resolve_image_tag() {
  if [ -n "${IMAGE_TAG:-}" ]; then echo "${IMAGE_TAG}"; return; fi
  echo "${IMAGE}:${CS_VERSION}"
}
TAG="$(resolve_image_tag)"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

test_serves_frontend() {
  log_header "Test :: ${IMAGE} отдаёт index.html"

  docker run -d --name "${CONTAINER}" \
    -e "CS_PUBLIC_WS_URL=${EXPECTED_URL}" \
    "${TAG}" >/dev/null

  local waited=0 body=""
  while [ "${waited}" -lt 60 ]; do
    body="$(docker exec "${CONTAINER}" wget -qO- http://127.0.0.1/index.html 2>/dev/null || true)"
    if [ -n "${body}" ]; then break; fi
    sleep 2
    waited=$((waited + 2))
  done

  if assert_contain "${body}" "<!doctype html" "index.html должен отдаваться как HTML"; then
    log_success "index.html отдаётся"
  else
    log_failure "лог контейнера:"
    docker logs --tail 30 "${CONTAINER}" 2>&1 | sed 's/^/    /' >&2 || true
    TEST_FAILED=1
    return 1
  fi
}

test_config_json() {
  log_header "Test :: config.json содержит адрес сервера взаимодействия"

  local config
  config="$(docker exec "${CONTAINER}" wget -qO- http://127.0.0.1/config.json 2>/dev/null || true)"

  if assert_contain "${config}" "${EXPECTED_URL}" "serverURL должен подставляться из CS_PUBLIC_WS_URL"; then
    log_success "config.json: ${config}"
  else
    log_failure "config.json не содержит ${EXPECTED_URL}"
    TEST_FAILED=1
  fi

  if assert_contain "${config}" "serverURL" "в config.json должно быть поле serverURL"; then
    log_success "поле serverURL присутствует"
  else
    TEST_FAILED=1
  fi
}

test_serves_frontend || true
test_config_json || true

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
