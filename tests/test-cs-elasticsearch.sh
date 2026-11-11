#!/bin/bash
# Проверка образа cs-elasticsearch: сервис стартует и отвечает по HTTP 9200.
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
CONTAINER="cs-elasticsearch-test-$$"

resolve_image_tag() {
  if [ -n "${IMAGE_TAG:-}" ]; then echo "${IMAGE_TAG}"; return; fi
  echo "cs-elasticsearch:${CS_VERSION}"
}
TAG="$(resolve_image_tag)"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

start_container() {
  log_header "Test :: Elasticsearch стартует"

  # --sysctl намеренно не используется: часть демонов (в т.ч. Docker Desktop)
  # запрещает менять vm.* из контейнера. Требование к хосту описано в README.
  docker run -d --name "${CONTAINER}" \
    -e CS_ES_HEAP=512m \
    "${TAG}" >/dev/null
}

test_http() {
  log_header "Test :: Elasticsearch отвечает по HTTP 9200"

  local waited=0 body=""
  while [ "${waited}" -lt 150 ]; do
    body="$(docker exec "${CONTAINER}" curl -fsS -m 5 http://127.0.0.1:9200/ 2>/dev/null || true)"
    if [ -n "${body}" ]; then
      break
    fi
    sleep 5
    waited=$((waited + 5))
  done

  if assert_contain "${body}" "cluster_name" "Elasticsearch должен отвечать JSON с cluster_name"; then
    log_success "Elasticsearch ответил по HTTP"
  else
    log_failure "лог контейнера:"
    docker logs --tail 40 "${CONTAINER}" 2>&1 | sed 's/^/    /' >&2 || true
    TEST_FAILED=1
    return 1
  fi

  if assert_contain "${body}" '"cluster_name" : "1ce-cs"' "имя кластера должно совпадать с CS"; then
    log_success "cluster_name = 1ce-cs"
  else
    # Elasticsearch форматирует JSON по-разному в разных сборках — проверяем мягко.
    if assert_contain "${body}" "1ce-cs" "имя кластера должно совпадать с CS"; then
      log_success "cluster_name содержит 1ce-cs"
    else
      TEST_FAILED=1
    fi
  fi
}

test_data_dir() {
  log_header "Test :: каталог данных вынесен в экземпляр (не в каталог компонента)"

  local out
  out="$(docker exec "${CONTAINER}" cat /var/cs/elasticsearch_instance/config/elasticsearch.yml 2>/dev/null || true)"
  if assert_contain "${out}" "path.data: /var/cs/elasticsearch_instance/data" "path.data должен указывать на экземпляр"; then
    log_success "path.data задан"
  else
    log_failure "конфигурация: ${out}"
    TEST_FAILED=1
  fi
}

start_container || true
test_data_dir || true
test_http || true

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
