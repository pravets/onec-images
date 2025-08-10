#!/bin/bash
set -euo pipefail

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  # .env may not exist locally; ignore if missing
  [ -f .env ] && source .env || true
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../tools/assert.sh"

# Resolve image tag from env or defaults (matches build-onec-full.sh scheme)
resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  if [[ -z "${ONEC_VERSION:-}" ]]; then
    log_failure "ONEC_VERSION не задан и IMAGE_TAG пуст — невозможно определить тег образа"
    exit 1
  fi
  echo "${prefix}onec-full:${ONEC_VERSION}${CI_SUFFIX:-}"
}

cleanup() {
  # Clean both container and temp dir if they exist
  if [[ -n "${CONTAINER_NAME:-}" ]]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
  if [[ -n "${HOST_TMP_DIR:-}" && -d "${HOST_TMP_DIR:-}" ]]; then
    rm -rf "$HOST_TMP_DIR" || true
  fi
}

trap cleanup EXIT


test_create_infobase() {
  log_header "Test :: 1cv8 CREATEINFOBASE"

  local tag
  tag="$(resolve_image_tag)"

  # Use named container to be able to docker cp artifacts from /tmp
  CONTAINER_NAME="onec-full-test-$(date +%s)-$RANDOM"
  HOST_TMP_DIR="$(mktemp -d)"

  # Run in detached mode to stream logs while preventing host-side hang
  # We do not mount host /tmp to avoid X11 socket ownership issues; artifacts will be copied after.
  set +e
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run -d --entrypoint bash --name "$CONTAINER_NAME" "$tag" -lc '
    set -e
    xvfb-run 1cv8 CREATEINFOBASE "File=/tmp/base" /DumpResult "/tmp/result.txt" /Out "/tmp/log.txt"
    exit 0
  ' >/dev/null 2>&1
  # Wait with timeout and stream logs
  if ! status=$(timeout 300s docker wait "$CONTAINER_NAME"); then
    log_failure "Контейнер не завершился за 300 секунд"
    docker logs "$CONTAINER_NAME" || true
    set -e
    exit 1
  fi
  docker logs "$CONTAINER_NAME" || true

  set -e

  # Try to copy artifacts regardless of exit code to aid diagnostics
  docker cp "$CONTAINER_NAME:/tmp/result.txt" "$HOST_TMP_DIR/result.txt" >/dev/null 2>&1 || true
  docker cp "$CONTAINER_NAME:/tmp/log.txt" "$HOST_TMP_DIR/log.txt" >/dev/null 2>&1 || true
  docker cp "$CONTAINER_NAME:/tmp/base/1Cv8.1CD" "$HOST_TMP_DIR/1Cv8.1CD" >/dev/null 2>&1 || true

  # Validate result.txt == 0 (sanitize digits only to avoid BOM/CRLF issues)
  if [[ -f "$HOST_TMP_DIR/result.txt" ]]; then
    local expected="0"
    local raw actual
    raw="$(cat "$HOST_TMP_DIR/result.txt" || true)"
    actual="$(LC_ALL=C tr -cd '0-9' < "$HOST_TMP_DIR/result.txt")"
    if ! assert_eq "$expected" "$actual" "Ожидали код результата 0"; then
      echo "hexdump(result.txt):"; hexdump -C "$HOST_TMP_DIR/result.txt" || true
      exit 1
   fi
  else
    log_failure "Файл /tmp/result.txt не создан"
    exit 1
  fi
  # Validate log contains expected message
  if [[ -f "$HOST_TMP_DIR/log.txt" ]]; then
    local expected
    expected='Создание информационной базы ("File=/tmp/base;Locale = "ru_RU";") успешно завершено'
    local log_content
    log_content="$(cat "$HOST_TMP_DIR/log.txt")"
    if assert_contain "$log_content" "$expected" "Лог не содержит ожидаемое сообщение"; then
      :
    else
      exit 1
    fi
  else
    log_failure "Файл /tmp/log.txt не создан"
    exit 1
  fi

  # Validate database file exists
  if ! [[ -f "$HOST_TMP_DIR/1Cv8.1CD" ]]; then
    log_failure "Файл /tmp/base/1Cv8.1CD не создан"
    exit 1
  fi

  log_success "CREATEINFOBASE test passed"
}

# Run test
test_create_infobase
