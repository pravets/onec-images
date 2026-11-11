#!/bin/bash
# Проверка образа cs-server: конфигурация экземпляра формируется из переменных
# окружения. Полноценный старт CS проверяется в tests/test-cs-stack.sh.
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
CONTAINER="cs-server-test-$$"
CONFIG_DIR="/var/cs/cs_instance/config"

resolve_image_tag() {
  if [ -n "${IMAGE_TAG:-}" ]; then echo "${IMAGE_TAG}"; return; fi
  echo "cs-server:${CS_VERSION}"
}
TAG="$(resolve_image_tag)"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

start_container() {
  log_header "Test :: контейнер готовит конфигурацию"
  # CMD подменён на sleep: нужен только этап подготовки (prepare), без запуска CS.
  docker run -d --name "${CONTAINER}" \
    -e CS_DB_URL='jdbc:postgresql://db.example:5432/cs_db?currentSchema=public' \
    -e CS_DB_USER=db_user \
    -e CS_DB_PASSWORD=db_pass \
    -e CS_ADMIN_PASSWORD=s3cret \
    -e CS_WS_PORT=18086 \
    -e CS_ES_ADDRESSES=es.example:9300 \
    -e CS_HAZELCAST_ADDRESSES=hc.example \
    -e CS_VIDEO_ENABLED=true \
    "${TAG}" sleep 600 >/dev/null

  local waited=0
  while [ "${waited}" -lt 120 ]; do
    # Маркер ставится точкой входа после всех prepare-скриптов: читать конфигурацию
    # раньше нельзя — jdbc.yml появляется ещё до конца подготовки.
    if docker exec "${CONTAINER}" test -f "/var/cs/.prepared" >/dev/null 2>&1; then
      log_success "конфигурация подготовлена за ${waited}с"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  log_failure "конфигурация не подготовлена за 120с"
  docker logs --tail 60 "${CONTAINER}" 2>&1 | sed 's/^/    /' >&2 || true
  TEST_FAILED=1
  return 1
}

config_contains() {
  local file="$1" needle="$2" description="$3"
  local content
  content="$(docker exec "${CONTAINER}" cat "${CONFIG_DIR}/${file}" 2>/dev/null || true)"
  if assert_contain "${content}" "${needle}" "${description}"; then
    log_success "${file}: ${description}"
  else
    log_failure "${file} не содержит '${needle}'"
    printf '%s\n' "${content}" | sed 's/^/    /' >&2
    TEST_FAILED=1
  fi
}

config_absent() {
  local file="$1" description="$2"
  if docker exec "${CONTAINER}" test -e "${CONFIG_DIR}/${file}" >/dev/null 2>&1; then
    log_failure "файл ${file} не должен создаваться: ${description}"
    TEST_FAILED=1
  else
    log_success "${file} отсутствует: ${description}"
  fi
}

check_configuration() {
  log_header "Test :: значения конфигурации взяты из окружения"

  config_contains "jdbc.yml" "jdbc:postgresql://db.example:5432/cs_db" "URL СУБД"
  config_contains "jdbc.yml" "db_user" "пользователь СУБД"
  config_contains "jdbc.yml" "db_pass" "пароль СУБД"
  config_contains "jdbc.yml" "privileged" "пул privileged"
  config_contains "websocket.yml" "18086" "порт WebSocket"
  config_contains "maintenance.yml" "0.0.0.0" "адрес админ-REST слушается наружу"
  config_contains "http_security.yml" "s3cret" "пароль администратора из env"
  config_contains "elasticsearch.yml" "es.example:9300" "адрес Elasticsearch"
  config_contains "hazelcast.yml" "hc.example" "адрес Hazelcast"
  config_contains "video.yml" "enabled: true" "видеосвязь включена"
  config_contains "logging.yml" "type: console" "консольный обработчик логов"
}

test_start_container() { start_container; }
test_check_configuration() {
  docker exec "${CONTAINER}" test -f /var/cs/.prepared >/dev/null 2>&1 || {
    log_failure "проверка конфигурации пропущена: конфигурация не готова"
    TEST_FAILED=1
    return 1
  }
  check_configuration
}

test_start_container || true
test_check_configuration || true

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
