#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI:-}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"	
else
    echo "The script is running in CI";
fi

source "${SCRIPT_DIR}/../scripts/docker_login.sh"
source "${SCRIPT_DIR}/../tools/assert.sh"

if [[ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]] ;
then
    docker system prune -af
fi

last_arg="."
if [[ $NO_CACHE = "true" ]] ; then
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

DOCKER_BUILDKIT=1 docker build \
    --pull \
    --build-arg EDT_VERSION="$EDT_VERSION" \
    --build-arg ONEC_USERNAME="$ONEC_USERNAME" \
    --build-arg ONEC_PASSWORD="$ONEC_PASSWORD" \
    -t $DOCKER_REGISTRY_URL/edt:$edt_version \
    -f "${SCRIPT_DIR}/../src/edt/${DOCKERFILE_NAME}" \
    $last_arg

if ./tests/test-edt.sh; then
    docker push $DOCKER_REGISTRY_URL/edt:$edt_version
    source "${SCRIPT_DIR}/../scripts/cleanup.sh"
else
    log_failure "ERROR: Tests failed. Docker image will not be pushed."
    source "${SCRIPT_DIR}/../scripts/cleanup.sh"
    exit 1
fi
exit 0
