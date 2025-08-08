#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI:-}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"
else
    echo "The script is running in CI"
fi

source "${SCRIPT_DIR}/../scripts/prepare_executor_api_key.sh"
source "${SCRIPT_DIR}/../tools/assert.sh"

# Defaults for CI-friendly behavior
PUSH_IMAGE=${PUSH_IMAGE:-true}

if [[ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]] ;
then
    docker system prune -af
fi

last_arg="."
if [[ "${NO_CACHE:-}" = "true" ]] ; then
    last_arg="--no-cache ."
fi

[[ -z "${EXECUTOR_VERSION:-}" ]] && { log_failure "Переменная EXECUTOR_VERSION не задана"; exit 1; }
executor_version=$EXECUTOR_VERSION

# Form the image tag; allow local tag without registry for CI builds
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}executor:${executor_version}${CI_SUFFIX:-}"

DOCKER_BUILDKIT=1 docker build \
    --secret id=dev1c_executor_api_key,src=/tmp/dev1c_executor_api_key.txt \
    --pull \
    --build-arg EXECUTOR_VERSION="$EXECUTOR_VERSION" \
    -t "$IMAGE_TAG" \
    -f "${SCRIPT_DIR}/../src/executor/Dockerfile" \
    $last_arg

shred -fzu "/tmp/dev1c_executor_api_key.txt" || true

# Run tests against the built image
if IMAGE_TAG="$IMAGE_TAG" ./tests/test-executor.sh; then
    if [[ "$PUSH_IMAGE" == "true" ]]; then
        # Login to registry only if we intend to push
        source "${SCRIPT_DIR}/../scripts/docker_login.sh"
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
