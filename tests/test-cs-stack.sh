#!/bin/bash
# Сквозная проверка стека 1С:Сервера взаимодействия.
#
# Поднимает внешнюю PostgreSQL 15, Hazelcast, Elasticsearch и сам CS в одной
# docker-сети, выполняет регистрацию БД через bootstrap и проверяет /rs/health.
# Это единственный тест, который доказывает, что компоненты работают вместе.
set -euo pipefail

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  [ -f .env ] && source .env || true
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/tools/assert.sh"

TEST_FAILED=0
CS_VERSION="${CS_VERSION:-30.0.42}"
SUFFIX="$$"

PREFIX=""
if [ -n "${DOCKER_REGISTRY_URL:-}" ]; then
  PREFIX="${DOCKER_REGISTRY_URL}/"
fi

NET="cs-stack-net-${SUFFIX}"
PG="cs-stack-pg-${SUFFIX}"
HC="cs-stack-hc-${SUFFIX}"
ES="cs-stack-es-${SUFFIX}"
SRV="cs-stack-srv-${SUFFIX}"
S3="cs-stack-s3-${SUFFIX}"

HOST_WS_PORT="${STACK_WS_PORT:-18086}"
HOST_ADMIN_PORT="${STACK_ADMIN_PORT:-18087}"
HOST_S3_PORT="${STACK_S3_PORT:-19000}"
DB_NAME="cs_db"
DB_USER="cs"
DB_PASSWORD="cs_pass"
ADMIN_PASSWORD="admin_pass"
HZ_GROUP="1ce-cs"
HZ_PASSWORD="cs-pass"
S3_BUCKET="cs-bucket"
S3_ACCESS_KEY="rustfs"
S3_SECRET_KEY="rustfs12345"
S3_READY=false

SERVER_IMAGE="${PREFIX}cs-server:${CS_VERSION}"
HAZELCAST_IMAGE="${PREFIX}cs-hazelcast:${CS_VERSION}"
ELASTICSEARCH_IMAGE="${PREFIX}cs-elasticsearch:${CS_VERSION}"
RUSTFS_IMAGE="${RUSTFS_IMAGE:-rustfs/rustfs:latest}"
AWS_CLI_IMAGE="${AWS_CLI_IMAGE:-amazon/aws-cli:latest}"

cleanup() {
  docker rm -f "${SRV}" "${ES}" "${HC}" "${PG}" "${S3}" >/dev/null 2>&1 || true
  docker network rm "${NET}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_exec() {
  # wait_for_exec <описание> <таймаут> <команда...>
  local description="$1" timeout="$2"; shift 2
  local waited=0
  while [ "${waited}" -lt "${timeout}" ]; do
    if "$@" >/dev/null 2>&1; then
      log_success "${description} готов за ${waited}с"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  log_failure "${description} не готов за ${timeout}с"
  TEST_FAILED=1
  return 1
}

test_compose_valid() {
  log_header "Test :: compose-файл корректен"

  # Относительные пути: docker compose получает их без преобразования
  # (важно при запуске тестов из Git Bash на Windows).
  if (cd "${REPO_ROOT}" && docker compose -f compose/cs/compose.yaml \
      --env-file compose/cs/.env.example config --quiet >/dev/null 2>&1); then
    log_success "compose/cs/compose.yaml проходит валидацию"
  else
    log_failure "compose/cs/compose.yaml не проходит валидацию docker compose config"
    (cd "${REPO_ROOT}" && docker compose -f compose/cs/compose.yaml \
      --env-file compose/cs/.env.example config --quiet 2>&1 | sed 's/^/    /' >&2) || true
    TEST_FAILED=1
  fi
}

test_start_postgres() {
  log_header "Test :: внешняя PostgreSQL 15"

  docker network create "${NET}" >/dev/null

  docker run -d --name "${PG}" --network "${NET}" \
    -e POSTGRES_USER="${DB_USER}" \
    -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
    -e POSTGRES_DB="${DB_NAME}" \
    postgres:15 >/dev/null

  wait_for_exec "PostgreSQL" 120 docker exec "${PG}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" || return 1

  # Расширение требуется серверу взаимодействия (руководство, раздел 4.4).
  if docker exec "${PG}" psql -U "${DB_USER}" -d "${DB_NAME}" \
      -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' >/dev/null 2>&1; then
    log_success "расширение uuid-ossp установлено"
  else
    log_failure "не удалось установить расширение uuid-ossp"
    TEST_FAILED=1
    return 1
  fi
}

test_start_hazelcast() {
  log_header "Test :: Hazelcast в сети стека"

  docker run -d --name "${HC}" --network "${NET}" \
    -e "CS_HAZELCAST_GROUP_NAME=${HZ_GROUP}" \
    -e "CS_HAZELCAST_GROUP_PASSWORD=${HZ_PASSWORD}" \
    "${HAZELCAST_IMAGE}" >/dev/null

  wait_for_exec "Hazelcast" 150 \
    docker exec "${HC}" bash -c 'exec 3<>/dev/tcp/127.0.0.1/5701' || return 1
}

test_start_elasticsearch() {
  log_header "Test :: Elasticsearch в сети стека"

  docker run -d --name "${ES}" --network "${NET}" \
    -e CS_ES_HEAP=512m \
    -e "CS_ES_CLUSTER_NAME=${HZ_GROUP}" \
    "${ELASTICSEARCH_IMAGE}" >/dev/null

  wait_for_exec "Elasticsearch" 180 \
    docker exec "${ES}" curl -fsS -m 5 http://127.0.0.1:9200/ || return 1
}

test_start_s3() {
  log_header "Test :: S3-хранилище RustFS"

  # Профиль s3 необязателен: если образы недоступны, этап пропускается,
  # чтобы тест не падал из-за внешнего реестра.
  if ! docker pull "${RUSTFS_IMAGE}" >/dev/null 2>&1; then
    echo "[WARN] образ ${RUSTFS_IMAGE} недоступен — проверка S3 пропущена" >&2
    return 0
  fi
  if ! docker pull "${AWS_CLI_IMAGE}" >/dev/null 2>&1; then
    echo "[WARN] образ ${AWS_CLI_IMAGE} недоступен — проверка S3 пропущена" >&2
    return 0
  fi

  docker run -d --name "${S3}" --network "${NET}" \
    -p "${HOST_S3_PORT}:9000" \
    -e "RUSTFS_ACCESS_KEY=${S3_ACCESS_KEY}" \
    -e "RUSTFS_SECRET_KEY=${S3_SECRET_KEY}" \
    -e RUSTFS_ADDRESS=:9000 \
    -e RUSTFS_CONSOLE_ADDRESS=:9001 \
    -e RUSTFS_CONSOLE_ENABLE=true \
    "${RUSTFS_IMAGE}" /data >/dev/null

  wait_for_exec "RustFS" 120 \
    curl -fsS -m 5 "http://127.0.0.1:${HOST_S3_PORT}/health" || return 0

  if docker run --rm --network "${NET}" \
      -e "AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY}" \
      -e "AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY}" \
      -e AWS_DEFAULT_REGION=eu-west-1 \
      -e AWS_EC2_METADATA_DISABLED=true \
      "${AWS_CLI_IMAGE}" \
      s3api create-bucket --bucket "${S3_BUCKET}" --endpoint-url "http://${S3}:9000" >/dev/null 2>&1; then
    log_success "бакет ${S3_BUCKET} создан"
    S3_READY=true
  else
    log_failure "не удалось создать бакет ${S3_BUCKET} — проверка регистрации S3 пропущена"
  fi
}

test_start_server() {
  log_header "Test :: CS стартует и отдаёт /rs/health"

  local -a s3_env=()
  if [ "${S3_READY}" = "true" ]; then
    s3_env=(
      -e "CS_S3_ENDPOINT=http://${S3}:9000"
      -e "CS_S3_BUCKET=${S3_BUCKET}"
      -e "CS_S3_ACCESS_KEY=${S3_ACCESS_KEY}"
      -e "CS_S3_SECRET_KEY=${S3_SECRET_KEY}"
      -e "CS_S3_REGION=eu-west-1"
      -e "CS_S3_SIGNATURE_VERSION=V4"
    )
  fi

  docker run -d --name "${SRV}" --network "${NET}" \
    -p "${HOST_WS_PORT}:8086" \
    -p "${HOST_ADMIN_PORT}:8087" \
    -e "CS_DB_URL=jdbc:postgresql://${PG}:5432/${DB_NAME}?currentSchema=public" \
    -e "CS_DB_USER=${DB_USER}" \
    -e "CS_DB_PASSWORD=${DB_PASSWORD}" \
    -e "CS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
    -e "CS_ES_ADDRESSES=${ES}:9300" \
    -e "CS_ES_CLUSTER_NAME=${HZ_GROUP}" \
    -e "CS_HAZELCAST_ADDRESSES=${HC}" \
    -e "CS_HAZELCAST_GROUP_NAME=${HZ_GROUP}" \
    -e "CS_HAZELCAST_GROUP_PASSWORD=${HZ_PASSWORD}" \
    "${s3_env[@]}" \
    "${SERVER_IMAGE}" >/dev/null

  local waited=0 body=""
  while [ "${waited}" -lt 420 ]; do
    body="$(curl -fsS -m 5 "http://127.0.0.1:${HOST_ADMIN_PORT}/rs/health" 2>/dev/null || true)"
    if [ -n "${body}" ]; then
      break
    fi
    if ! docker ps --format '{{.Names}}' | grep -qx "${SRV}"; then
      log_failure "контейнер CS завершился до готовности"
      docker logs --tail 80 "${SRV}" 2>&1 | sed 's/^/    /' >&2 || true
      TEST_FAILED=1
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done

  if [ -z "${body}" ]; then
    log_failure "административный REST не ответил за 420с"
    docker logs --tail 80 "${SRV}" 2>&1 | sed 's/^/    /' >&2 || true
    TEST_FAILED=1
    return 1
  fi
  log_success "административный REST доступен через ${waited}с"
}

test_bootstrap() {
  log_header "Test :: регистрация зависимостей (bootstrap) идемпотентна"

  local out
  if out="$(docker exec "${SRV}" /usr/local/bin/bootstrap-cs.sh 2>&1)"; then
    log_success "bootstrap выполнен"
  else
    log_failure "bootstrap завершился с ошибкой:"
    printf '%s\n' "${out}" | sed 's/^/    /' >&2
    TEST_FAILED=1
    return 1
  fi

  # Повторный запуск должен пройти без ошибок (идемпотентность через маркер).
  if docker exec "${SRV}" /usr/local/bin/bootstrap-cs.sh >/dev/null 2>&1; then
    log_success "повторный bootstrap не падает"
  else
    log_failure "повторный bootstrap завершился с ошибкой"
    TEST_FAILED=1
  fi

  # Так bootstrap запускает сервис init в compose: отдельный контейнер обращается
  # к административному REST по имени контейнера, а не по своему loopback.
  if out="$(docker run --rm --network "${NET}" \
      --entrypoint /usr/local/bin/bootstrap-cs.sh \
      -e "CS_ADMIN_HOST=${SRV}" \
      -e "CS_ADMIN_PORT=8087" \
      -e "CS_ADMIN_USER=admin" \
      -e "CS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
      -e "CS_DB_URL=jdbc:postgresql://${PG}:5432/${DB_NAME}?currentSchema=public" \
      -e "CS_DB_USER=${DB_USER}" \
      -e "CS_DB_PASSWORD=${DB_PASSWORD}" \
      -e "CS_BOOTSTRAP=always" \
      -e "CS_BOOTSTRAP_STRICT=true" \
      "${SERVER_IMAGE}" 2>&1)"; then
    if assert_contain "${out}" "уже зарегистрировано" \
        "отдельный контейнер должен видеть зависимости по сети"; then
      log_success "bootstrap из отдельного контейнера работает"
    else
      TEST_FAILED=1
    fi
  else
    log_failure "bootstrap из отдельного контейнера завершился с ошибкой:"
    printf '%s\n' "${out}" | sed 's/^/    /' >&2
    TEST_FAILED=1
  fi
}

test_health() {
  log_header "Test :: состояние компонентов в /rs/health"

  local body
  body="$(curl -fsS -m 10 -u "admin:${ADMIN_PASSWORD}" \
    "http://127.0.0.1:${HOST_ADMIN_PORT}/rs/health" 2>/dev/null || true)"

  if assert_contain "${body}" '"mainDbOk":true' "основная БД должна быть доступна"; then
    log_success "mainDbOk = true"
  else
    log_failure "health: ${body}"
    TEST_FAILED=1
  fi

  if assert_contain "${body}" '"available":true' "кластер Hazelcast должен быть активен"; then
    log_success "Hazelcast доступен"
  else
    TEST_FAILED=1
  fi

  if assert_contain "${body}" '"elasticsearchOk":true' "Elasticsearch должен быть доступен"; then
    log_success "elasticsearchOk = true"
  else
    TEST_FAILED=1
  fi
}

test_db_registered() {
  log_header "Test :: база данных зарегистрирована в CS"

  local body
  body="$(docker exec "${SRV}" curl -fsS -m 10 -u "admin:${ADMIN_PASSWORD}" \
    http://127.0.0.1:8087/admin/bucket_server 2>/dev/null || true)"

  if assert_contain "${body}" "${DB_NAME}" "в списке должна быть зарегистрированная БД"; then
    log_success "БД ${DB_NAME} зарегистрирована"
  else
    log_failure "ответ /admin/bucket_server: ${body}"
    TEST_FAILED=1
  fi
}

test_storage_registered() {
  log_header "Test :: S3-хранилище зарегистрировано в CS"

  if [ "${S3_READY}" != "true" ]; then
    echo "[WARN] проверка пропущена: S3-этап не выполнялся" >&2
    return 0
  fi

  local body
  body="$(docker exec "${SRV}" curl -fsS -m 10 -u "admin:${ADMIN_PASSWORD}" \
    http://127.0.0.1:8087/admin/storage_server 2>/dev/null || true)"

  if assert_contain "${body}" "${S3_BUCKET}" "в списке должно быть зарегистрированное хранилище"; then
    log_success "S3-хранилище ${S3_BUCKET} зарегистрировано"
  else
    log_failure "ответ /admin/storage_server: ${body}"
    TEST_FAILED=1
  fi
}

test_compose_valid || true
test_start_postgres || true
test_start_hazelcast || true
test_start_elasticsearch || true
test_start_s3 || true

if [ "${TEST_FAILED}" -eq 0 ]; then
  test_start_server || true
fi
if [ "${TEST_FAILED}" -eq 0 ]; then
  test_bootstrap || true
  test_health || true
  test_db_registered || true
  test_storage_registered || true
fi

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
