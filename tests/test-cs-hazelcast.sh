#!/bin/bash
# Проверка образа cs-hazelcast: экземпляр создаётся, сервис слушает порт 5701.
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
CS_VERSION="${CS_VERSION:-30.0.42}"
CONTAINER="cs-hazelcast-test-$$"

resolve_image_tag() {
  if [ -n "${IMAGE_TAG:-}" ]; then echo "${IMAGE_TAG}"; return; fi
  echo "cs-hazelcast:${CS_VERSION}"
}
TAG="$(resolve_image_tag)"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

test_start_and_listen() {
  log_header "Test :: Hazelcast стартует и слушает 5701"

  docker run -d --name "${CONTAINER}" "${TAG}" >/dev/null

  local waited=0 port_ok=0
  while [ "${waited}" -lt 120 ]; do
    if docker exec "${CONTAINER}" bash -c 'exec 3<>/dev/tcp/127.0.0.1/5701' >/dev/null 2>&1; then
      port_ok=1
      break
    fi
    sleep 3
    waited=$((waited + 3))
  done

  if assert_eq "1" "${port_ok}" "порт 5701 должен начать слушаться за 120с"; then
    log_success "Hazelcast слушает 5701"
  else
    log_failure "лог контейнера:"
    docker logs --tail 40 "${CONTAINER}" 2>&1 | sed 's/^/    /' >&2 || true
    TEST_FAILED=1
    return 1
  fi
}

test_instance_layout() {
  log_header "Test :: конфигурация экземпляра Hazelcast создана"

  if docker exec "${CONTAINER}" test -f /var/cs/hazelcast_instance/config/hazelcast.xml; then
    log_success "hazelcast.xml создан"
  else
    log_failure "hazelcast.xml отсутствует"
    TEST_FAILED=1
    return 1
  fi

  local group
  group="$(docker exec "${CONTAINER}" bash -c "grep -A1 '<name>' /var/cs/hazelcast_instance/config/hazelcast.xml | head -2" 2>/dev/null || true)"
  if assert_contain "${group}" "1ce-cs" "группа Hazelcast должна совпадать с CS"; then
    log_success "группа Hazelcast: 1ce-cs"
  else
    TEST_FAILED=1
  fi
}

test_start_and_listen || true
test_instance_layout || true

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
