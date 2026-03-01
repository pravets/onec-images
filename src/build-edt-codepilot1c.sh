#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI:-}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"
else
    echo "The script is running in CI"
fi

# Logging/assert helpers
source "${SCRIPT_DIR}/../tools/assert.sh"

# Defaults for CI-friendly behavior
PUSH_IMAGE=${PUSH_IMAGE:-true}

if [[ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]] ; then
    docker system prune -af
fi

cache_arg=()
if [[ "${NO_CACHE:-}" = "true" ]] ; then
    cache_arg=(--no-cache)
fi

[[ -z "${EDT_VERSION:-}" ]] && { echo "Переменная EDT_VERSION не задана" >&2; exit 1; }
edt_version=$EDT_VERSION

[[ -z "${EDT_CODEPILOT_VERSION:-}" ]] && { echo "Переменная EDT_CODEPILOT_VERSION не задана" >&2; exit 1; }

if [[ -z "${DOCKER_REGISTRY_URL:-}" ]]; then
    echo "Ошибка: для сборки edt-codepilot1c необходимо задать DOCKER_REGISTRY_URL (приватный реестр с образом edt)." >&2
    exit 1
fi

# Form the image tag; allow local tag without registry for CI builds
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}edt-codepilot1c:${edt_version}_${EDT_CODEPILOT_VERSION}${CI_SUFFIX:-}"
BASE_IMAGE_TAG="${registry_prefix}edt:${edt_version}"

if [[ "${FORCE_BUILD_BASE:-}" == "true" ]]; then
    echo "Принудительная локальная сборка базового образа edt:${edt_version} (FORCE_BUILD_BASE=true)"
    PUSH_IMAGE=${PUSH_IMAGE} EDT_VERSION="$edt_version" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-edt.sh"
elif ! docker image inspect "$BASE_IMAGE_TAG" >/dev/null 2>&1; then
    if [[ -n "${DOCKER_LOGIN:-}" && -n "${DOCKER_PASSWORD:-}" && -n "${DOCKER_REGISTRY_URL:-}" ]]; then
        source "${SCRIPT_DIR}/../scripts/docker_login.sh"
    fi

    if docker pull "$BASE_IMAGE_TAG"; then
        echo "Базовый образ получен из реестра: $BASE_IMAGE_TAG"
    else
        echo "Не удалось получить базовый образ из реестра: $BASE_IMAGE_TAG" >&2
        echo "Выполняю локальную сборку базового образа edt:${edt_version}" >&2
        PUSH_IMAGE=${PUSH_IMAGE} EDT_VERSION="$edt_version" CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" "${SCRIPT_DIR}/build-edt.sh"
    fi
fi

if [[ "$PUSH_IMAGE" == "true" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

DOCKER_BUILDKIT=1 docker build \
    "${cache_arg[@]}" \
    --build-arg EDT_VERSION="$EDT_VERSION" \
    --build-arg EDT_CODEPILOT_VERSION="$EDT_CODEPILOT_VERSION" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL}" \
    -t "$IMAGE_TAG" \
    -f "${SCRIPT_DIR}/edt-codepilot1c/Dockerfile" \
    "${SCRIPT_DIR}/edt-codepilot1c"

# Run tests against the built image
if IMAGE_TAG="$IMAGE_TAG" ./tests/test-edt-codepilot1c.sh; then
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
