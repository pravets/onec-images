#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CI}" ]; then
    echo "The script is not running in CI"
    source "${SCRIPT_DIR}/../scripts/load_env.sh"	
else
    echo "The script is running in CI";
fi

source "${SCRIPT_DIR}/../scripts/docker_login.sh"
source "${SCRIPT_DIR}/../scripts/prepare_executor_api_key.sh"
source "${SCRIPT_DIR}/../tools/assert.sh"

if [[ $DOCKER_SYSTEM_PRUNE = "true" ]] ;
then
    docker system prune -af
fi

last_arg="."
if [[ $NO_CACHE = "true" ]] ; then
	last_arg="--no-cache ."
fi

[[ -z "${EXECUTOR_VERSION:-}" ]] && log_failure "Переменная EXECUTOR_VERSION не задана"
executor_version=$EXECUTOR_VERSION

DOCKER_BUILDKIT=1 docker build \
    --secret id=dev1c_executor_api_key,src=dev1c_executor_api_key.txt \
    --pull \
    --build-arg EXECUTOR_VERSION="$EXECUTOR_VERSION" \
    -t $DOCKER_REGISTRY_URL/executor:$executor_version \
    -f "${SCRIPT_DIR}/../src/executor/Dockerfile" \
    $last_arg

shred -u dev1c_executor_api_key.txt

if ./tests/test-executor.sh; then
    docker push $DOCKER_REGISTRY_URL/executor:$executor_version
    source "${SCRIPT_DIR}/../scripts/cleanup.sh"
else
    log_failure "ERROR: Tests failed. Docker image will not be pushed."
    source "${SCRIPT_DIR}/../scripts/cleanup.sh"
    exit 1
fi
exit 0
