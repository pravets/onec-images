#!/bin/bash
# Проверка базового образа cs-base: JRE 11, ring, установленные компоненты,
# непривилегированный пользователь и общие скрипты.
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

resolve_image_tag() {
  if [ -n "${IMAGE_TAG:-}" ]; then
    echo "${IMAGE_TAG}"
    return
  fi
  echo "cs-base:${CS_VERSION}"
}

TAG="$(resolve_image_tag)"

test_java() {
  log_header "Test :: JRE 11 установлена"
  local out
  out="$(docker run --rm --entrypoint java "${TAG}" -version 2>&1 || true)"
  if assert_contain "${out}" "version \"11." "в образе должна быть Java 11"; then
    log_success "Java 11 найдена"
  else
    TEST_FAILED=1
  fi
}

test_ring() {
  log_header "Test :: утилита ring доступна"
  local out
  out="$(docker run --rm --entrypoint ring "${TAG}" --version 2>&1 || true)"
  if assert_contain "${out}" "0.19" "ring должен отвечать на --version"; then
    log_success "ring: ${out}"
  else
    TEST_FAILED=1
  fi
}

test_gawk() {
  log_header "Test :: gawk установлен (ring использует gensub)"
  local out
  out="$(docker run --rm --entrypoint bash "${TAG}" -c 'readlink -f "$(command -v awk)"' 2>&1 || true)"
  if assert_contain "${out}" "gawk" "awk должен указывать на gawk"; then
    log_success "awk -> ${out}"
  else
    TEST_FAILED=1
  fi
}

test_components() {
  log_header "Test :: компоненты продукта установлены"
  local dirs=(
    "1c-cs-server-small-*"
    "1c-cs-hazelcast-*"
    "1c-cs-elasticsearch-*"
    "1c-cs-site-*"
    "1c-cs-web-chat-*"
    "1c-enterprise-ring-*"
  )
  local pattern
  for pattern in "${dirs[@]}"; do
    if docker run --rm --entrypoint bash "${TAG}" -c "ls -d /opt/1C/1CE/components/${pattern} >/dev/null" >/dev/null 2>&1; then
      log_success "компонент на месте: ${pattern}"
    else
      log_failure "компонент отсутствует: ${pattern}"
      TEST_FAILED=1
    fi
  done
}

test_launchers() {
  log_header "Test :: лаунчеры компонентов исполняемы"
  local patterns=("1c-cs-server-small-*" "1c-cs-hazelcast-*" "1c-cs-elasticsearch-*")
  local pattern
  for pattern in "${patterns[@]}"; do
    if docker run --rm --entrypoint bash "${TAG}" -c "test -x \$(ls -d /opt/1C/1CE/components/${pattern})/bin/launcher" >/dev/null 2>&1; then
      log_success "лаунчер найден: ${pattern}"
    else
      log_failure "лаунчер отсутствует: ${pattern}"
      TEST_FAILED=1
    fi
  done
}

test_user() {
  log_header "Test :: пользователь cs создан и непривилегированный"
  local out
  out="$(docker run --rm --entrypoint id "${TAG}" cs 2>&1 || true)"
  if assert_contain "${out}" "uid=" "пользователь cs должен существовать"; then
    local uid
    uid="$(printf '%s' "${out}" | sed -E 's/^uid=([0-9]+).*/\1/')"
    if assert_gt "${uid}" 0 "cs не должен быть root"; then
      log_success "cs: ${out}"
    else
      TEST_FAILED=1
    fi
  else
    TEST_FAILED=1
  fi
}

test_helpers() {
  log_header "Test :: общие скрипты образа на месте"
  local files=(
    "/usr/local/lib/cs/lib-cs.sh"
    "/usr/local/bin/docker-entrypoint.sh"
    "/usr/local/bin/run-component.sh"
  )
  local file
  for file in "${files[@]}"; do
    if docker run --rm --entrypoint test "${TAG}" -x "${file}" >/dev/null 2>&1; then
      log_success "скрипт на месте: ${file}"
    else
      log_failure "скрипт отсутствует: ${file}"
      TEST_FAILED=1
    fi
  done
}

test_java || true
test_ring || true
test_gawk || true
test_components || true
test_launchers || true
test_user || true
test_helpers || true

if [ -n "${CI:-}" ]; then
  exit "${TEST_FAILED}"
fi
exit 0
