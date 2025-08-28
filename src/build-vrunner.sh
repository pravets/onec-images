#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI:-}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"
else
    echo "The script is running in CI"
fi

# Логи и ассерт-хелперы
source "${SCRIPT_DIR}/../tools/assert.sh"

# Defaults for CI-friendly behavior
PUSH_IMAGE=${PUSH_IMAGE:-true}

if [[ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]] ; then
    docker system prune -af
fi

last_arg=(.)
if [[ "${NO_CACHE:-}" = "true" ]] ; then
    last_arg=(--no-cache .)
fi

[[ -z "${ONEC_VERSION:-}" ]] && { log_failure "Переменная ONEC_VERSION не задана"; exit 1; }

onec_version=$ONEC_VERSION

# Формируем теги образов
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}vrunner:${onec_version}${CI_SUFFIX:-}"
BASE_IMAGE_TAG="${registry_prefix}onec-platform:${onec_version}"

if [[ -n "${DOCKER_LOGIN:-}" && -n "${DOCKER_PASSWORD:-}" && -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

# Убедимся, что базовый образ onec-platform доступен локально.
# Предпочитаем локальный образ без префикса (onec-platform:${onec_version}), затем с префиксом.
local_unprefixed="onec-platform:${onec_version}"
found_local=false

if docker image inspect "$local_unprefixed" >/dev/null 2>&1; then
    echo "Найден локальный образ: $local_unprefixed"
    BASE_IMAGE_TAG="$local_unprefixed"
    found_local=true
elif docker image inspect "$BASE_IMAGE_TAG" >/dev/null 2>&1; then
    echo "Найден локальный образ с префиксом: $BASE_IMAGE_TAG"
    found_local=true
fi

if ! $found_local; then
    # Попытка пуллить только если указан реальный реестр (не 'local' — тестовая метка для CI)
    if [[ -n "${DOCKER_REGISTRY_URL:-}" && "${DOCKER_REGISTRY_URL}" != "local" ]]; then
        if docker pull "$BASE_IMAGE_TAG"; then
            echo "Базовый образ получен из реестра: $BASE_IMAGE_TAG"
        else
            echo "Не удалось получить базовый образ из реестра: $BASE_IMAGE_TAG" >&2
            echo "Выполняю локальную сборку базового образа onec-platform:${onec_version}" >&2
            PUSH_IMAGE=${PUSH_IMAGE} ONEC_VERSION="$onec_version" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-onec-platform.sh"
        fi
    else
        echo "DOCKER_REGISTRY_URL пустой или равен 'local' — пропускаю попытку pull и строю локально" >&2
        echo "Выполняю локальную сборку базового образа onec-platform:${onec_version}" >&2
        PUSH_IMAGE=${PUSH_IMAGE} ONEC_VERSION="$onec_version" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-onec-platform.sh"
    fi
fi

# Логинимся в реестр, если требуется пуш
if [[ "$PUSH_IMAGE" == "true" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

# Сборка vrunner
DOCKER_BUILDKIT=1 docker build \
    --pull \
    --build-arg DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL}" \
    --build-arg ONEC_VERSION="${ONEC_VERSION}" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    -t "$IMAGE_TAG" \
    -f "${SCRIPT_DIR}/vrunner/Dockerfile" \
    "${last_arg[@]}"

# Тесты (если есть)
TEST_SCRIPT="${SCRIPT_DIR}/../tests/test-vrunner.sh"
if [[ -x "$TEST_SCRIPT" ]]; then
  if IMAGE_TAG="$IMAGE_TAG" "$TEST_SCRIPT"; then
      if [[ "$PUSH_IMAGE" == "true" ]]; then
          docker push "$IMAGE_TAG"
      else
          echo "Skipping push (PUSH_IMAGE=false)"
      fi
      source "${SCRIPT_DIR}/../scripts/cleanup.sh"
  else
      log_failure "ERROR: Tests failed. Docker image will not be pushed."
      source "${SCRIPT_DIR}/../scripts/cleanup.sh"
      exit 1
  fi
else
  echo "No tests found for vrunner. Skipping tests."
  if [[ "$PUSH_IMAGE" == "true" ]]; then
      docker push "$IMAGE_TAG"
  else
      echo "Skipping push (PUSH_IMAGE=false)"
  fi
  source "${SCRIPT_DIR}/../scripts/cleanup.sh"
fi

exit 0
