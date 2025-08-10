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

[[ -z "${ONEC_VERSION:-}" ]] && { log_failure "Переменная ONEC_VERSION не задана"; exit 1; }
onec_version=$ONEC_VERSION

# Form the image tag; allow local tag without registry for CI builds
registry_prefix=""
if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    registry_prefix="${DOCKER_REGISTRY_URL}/"
fi
IMAGE_TAG="${registry_prefix}onec-platform:${onec_version}${CI_SUFFIX:-}"

if [[ "$PUSH_IMAGE" == "true" ]]; then
    source "${SCRIPT_DIR}/../scripts/docker_login.sh"
fi

DOCKER_BUILDKIT=1 docker build \
    --pull \
    --secret id=onec_username,src=/tmp/onec_username \
    --secret id=onec_password,src=/tmp/onec_password \
    --build-arg ONEC_VERSION="$ONEC_VERSION" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    -t "$IMAGE_TAG" \
    -f "$(
        # Select Dockerfile by first three components of ONEC_VERSION
        version_prefix=$(echo "$ONEC_VERSION" | awk -F. '{print $1 "." $2 "." $3}')
        dockerfile_path="${SCRIPT_DIR}/../src/onec-platform/${version_prefix}.Dockerfile"
        if [[ ! -f "$dockerfile_path" ]]; then
            log_failure "Не найден подходящий Dockerfile для версии ${version_prefix}. Поддерживаются 8.3.22–8.3.27"
            exit 1
        fi
        echo "$dockerfile_path"
      )" \
    $last_arg

# Run tests against the built image if present
TEST_SCRIPT="${SCRIPT_DIR}/../tests/test-onec-platform.sh"
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
  echo "No tests found for onec-platform. Skipping tests."
  if [[ "$PUSH_IMAGE" == "true" ]]; then
      docker push "$IMAGE_TAG"
  else
      echo "Skipping push (PUSH_IMAGE=false)"
  fi
  source "${SCRIPT_DIR}/../scripts/cleanup.sh"
fi

exit 0
