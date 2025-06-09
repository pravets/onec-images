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

oscript_version="${OSCRIPT_VERSION}"

case "${oscript_version}" in
    1.*|lts|lts-dev|stable)
        dockerfile_dir="src/onescript/1"
        ;;
    2.*|dev|preview)
        dockerfile_dir="src/onescript/2"
        ;;
    *)
        echo "Unknown OSCRIPT_VERSION: ${oscript_version}"
        exit 1
        ;;
esac

docker build \
    --pull \
    --build-arg OSCRIPT_VERSION="${oscript_version}" \
    -t "${DOCKER_REGISTRY_URL}/oscript:${oscript_version}" \
    -f "${dockerfile_dir}/Dockerfile" \
    ${last_arg}

#docker push "${DOCKER_REGISTRY_URL}/oscript:${oscript_version}"
