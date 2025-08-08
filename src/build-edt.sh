#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI:-}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"
else
    echo "The script is running in CI"
fi

# Defaults for CI-friendly behavior
PUSH_IMAGE=${PUSH_IMAGE:-true}

# Always prepare credentials for 1C releases site (required for build)
source "${SCRIPT_DIR}/../scripts/prepare_onec_credentials.sh"
source "${SCRIPT_DIR}/../tools/assert.sh"

if [[ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]] ; then
    docker system prune -af
fi

last_arg="."
if [[ "${NO_CACHE:-}" = "true" ]] ; then
    last_arg="--no-cache ."
fi

[[ -z "${EDT_VERSION:-}" ]] && { log_failure "Переменная EDT_VERSION не задана"; exit 1; }
edt_version=$EDT_VERSION

MAJOR_VERSION=$(echo "$EDT_VERSION" | cut -d '.' -f 1)
if ! [[ "$MAJOR_VERSION" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: неверный формат версии (мажорная часть должна быть числом)" >&2
    exit 1
fi

MIN_SUPPORTED=2023
MAX_SUPPORTED=2024

if [ "$MAJOR_VERSION" -lt "$MIN_SUPPORTED" ] || [ "$MAJOR_VERSION" -gt "$MAX_SUPPORTED" ]; then
    echo "Ошибка: неподдерживаемая версия $MAJOR_VERSION. Поддерживаются версии от $MIN_SUPPORTED до $MAX_SUPPORTED" >&2
    exit 1
fi

DOCKERFILE_NAME="${MAJOR_VERSION}.Dockerfile"

# Form the image tag; allow local tag without registry for CI builds
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}edt:${edt_version}${CI_SUFFIX:-}"

# Login to registry only if we intend to push
if [[ "$PUSH_IMAGE" == "true" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

DOCKER_BUILDKIT=1 docker build \
    --pull \
    --secret id=onec_username,src=/tmp/onec_username \
    --secret id=onec_password,src=/tmp/onec_password \
    --build-arg EDT_VERSION="$EDT_VERSION" \
    -t "$IMAGE_TAG" \
    -f "${SCRIPT_DIR}/../src/edt/${DOCKERFILE_NAME}" \
    $last_arg

# Run tests against the built image
if IMAGE_TAG="$IMAGE_TAG" ./tests/test-edt.sh; then
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
