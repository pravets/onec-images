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

# Версия onec-platform (источник hbk-файлов) прибита молотком —
# переопределяется через ONEC_VERSION при сборке.
ONEC_VERSION=${ONEC_VERSION:-8.3.27.2214}

# Версия базового образа sonar-scanner-cli — переопределяется через
# SONAR_SCANNER_VERSION при сборке.
SONAR_SCANNER_VERSION=${SONAR_SCANNER_VERSION:-12.1.0.3233_8.0.1}

# Формируем теги образов
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}bsl-sonar-scanner-cli:${ONEC_VERSION}${CI_SUFFIX:-}"

# Резолвим базовый образ onec-platform (источник hbk-файлов).
# Предпочитаем локальный образ без префикса (onec-platform:${ONEC_VERSION}),
# затем с префиксом реестра; иначе pull из реестра; в крайнем случае —
# локальная сборка onec-platform.
ONEC_BASE_IMAGE=""
local_unprefixed="onec-platform:${ONEC_VERSION}"
local_prefixed="${registry_prefix}onec-platform:${ONEC_VERSION}"

if docker image inspect "$local_unprefixed" >/dev/null 2>&1; then
    echo "Найден локальный образ: $local_unprefixed"
    ONEC_BASE_IMAGE="$local_unprefixed"
elif docker image inspect "$local_prefixed" >/dev/null 2>&1; then
    echo "Найден локальный образ с префиксом: $local_prefixed"
    ONEC_BASE_IMAGE="$local_prefixed"
elif [[ -n "${DOCKER_REGISTRY_URL:-}" && "${DOCKER_REGISTRY_URL}" != "local" ]]; then
    echo "Базовый образ не найден локально. Пытаюсь получить из реестра: $local_prefixed"
    if [[ -n "${DOCKER_LOGIN:-}" && -n "${DOCKER_PASSWORD:-}" && -n "${DOCKER_REGISTRY_URL:-}" ]]; then
        source "${SCRIPT_DIR}/../scripts/docker_login.sh"
    fi
    if docker pull "$local_prefixed"; then
        echo "Базовый образ получен из реестра: $local_prefixed"
        ONEC_BASE_IMAGE="$local_prefixed"
    else
        echo "Не удалось получить базовый образ из реестра: $local_prefixed" >&2
        echo "Выполняю локальную сборку базового образа onec-platform:${ONEC_VERSION}" >&2
        PUSH_IMAGE=${PUSH_IMAGE} ONEC_VERSION="$ONEC_VERSION" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-onec-platform.sh"
        # build-onec-platform.sh тегирует образ как ${DOCKER_REGISTRY_URL}/onec-platform:${ONEC_VERSION}
        ONEC_BASE_IMAGE="${registry_prefix}onec-platform:${ONEC_VERSION}"
    fi
else
    echo "DOCKER_REGISTRY_URL пустой или равен 'local' — пропускаю pull, строю onec-platform локально" >&2
    echo "Выполняю локальную сборку базового образа onec-platform:${ONEC_VERSION}" >&2
    PUSH_IMAGE=${PUSH_IMAGE} ONEC_VERSION="$ONEC_VERSION" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-onec-platform.sh"
    # build-onec-platform.sh тегирует образ как ${DOCKER_REGISTRY_URL}/onec-platform:${ONEC_VERSION}
    # (при пустом DOCKER_REGISTRY_URL — без префикса, при 'local' — с префиксом local/)
    ONEC_BASE_IMAGE="${registry_prefix}onec-platform:${ONEC_VERSION}"
fi

[[ -z "$ONEC_BASE_IMAGE" ]] && { log_failure "Не удалось определить базовый образ onec-platform"; exit 1; }

# Логинимся в реестр, если требуется пуш
if [[ "$PUSH_IMAGE" == "true" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

# Сборка bsl-sonar-scanner-cli
DOCKER_BUILDKIT=1 docker build \
    --build-arg ONEC_VERSION="${ONEC_VERSION}" \
    --build-arg SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION}" \
    --build-arg ONEC_BASE_IMAGE="${ONEC_BASE_IMAGE}" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    -t "$IMAGE_TAG" \
    -f "${SCRIPT_DIR}/bsl-sonar-scanner-cli/Dockerfile" \
    "${last_arg[@]}"

# Тесты — обязательны: без исполняемого теста образ не публикуется.
TEST_SCRIPT="${SCRIPT_DIR}/../tests/test-bsl-sonar-scanner-cli.sh"
if [[ ! -x "$TEST_SCRIPT" ]]; then
    log_failure "Не найден исполняемый тест: $TEST_SCRIPT"
    source "${SCRIPT_DIR}/../scripts/cleanup.sh"
    exit 1
fi

# Запускаем тесты с CI=true, чтобы код завершения отражал провал тестов
# (вне CI тестовый скрипт возвращает 0 даже при TEST_FAILED=1)
if CI=true IMAGE_TAG="$IMAGE_TAG" ONEC_VERSION="$ONEC_VERSION" "$TEST_SCRIPT"; then
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

exit 0
