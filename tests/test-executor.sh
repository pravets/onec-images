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

# Resolve image tag from env or defaults
resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  echo "${prefix}executor:${EXECUTOR_VERSION}"
}

# Проверяет, соответствует ли версия Docker-образа executor ожидаемому формату.
#
# Использует переменные окружения EXECUTOR_VERSION и DOCKER_REGISTRY_URL для формирования ожидаемой и фактической версии.
# Сравнивает версию, полученную из вывода контейнера, с ожидаемой строкой, преобразованной из EXECUTOR_VERSION.
#
# Globals:
#   EXECUTOR_VERSION - версия executor, используемая для проверки.
#   DOCKER_REGISTRY_URL - адрес реестра Docker, из которого берётся образ.
#
# Outputs:
#   Выводит сообщения об успехе или неудаче теста в STDOUT.
#
# Example:
#
#   test_executor_version
test_executor_version() {
  log_header "Test :: executor version"

  # Проверяем, что переменная EXECUTOR_VERSION задана
  if [[ -z "${EXECUTOR_VERSION:-}" ]]; then
    log_failure "EXECUTOR_VERSION не задан — прерываем тест"
    exit 1
  fi

  local expected actual tag
  # If EXECUTOR_VERSION already contains a hyphen (e.g. 9.0.0-1), use it as-is.
  # Otherwise, replace the last dot with a hyphen (e.g. 9.0.0.1 -> 9.0.0-1).
  if [[ "$EXECUTOR_VERSION" == *-* ]]; then
    expected="$EXECUTOR_VERSION"
  else
    expected=$(echo "$EXECUTOR_VERSION" | sed 's/\(.*\)\./\1-/')
  fi
  tag="$(resolve_image_tag)"
  actual=$(docker run --rm "$tag" --version)

  if assert_contain "$actual" "$expected"; then
    log_success "executor version test passed"
  else
    log_failure "executor version test failed"
  fi
}

# test calls
test_executor_version
