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

TEST_FAILED=0

# Дефолт совпадает с build-скриптом (версия onec-platform прибита молотком)
ONEC_VERSION=${ONEC_VERSION:-8.3.27.2214}

# Resolve image tag from env or defaults (matches build-bsl-sonar-scanner-cli.sh scheme)
resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  echo "${prefix}bsl-sonar-scanner-cli:${ONEC_VERSION}${CI_SUFFIX:-}"
}

test_hbk_files_present() {
  log_header "Test :: hbk files present at onec-platform paths"

  local tag
  tag="$(resolve_image_tag)"

  local paths=(
    "/opt/1cv8/x86_64/${ONEC_VERSION}/shcntx_root.hbk"
    "/opt/1cv8/x86_64/${ONEC_VERSION}/shcntx_ru.hbk"
    "/opt/1cv8/x86_64/${ONEC_VERSION}/shlang_root.hbk"
    "/opt/1cv8/x86_64/${ONEC_VERSION}/shlang_ru.hbk"
  )

  local p
  for p in "${paths[@]}"; do
    if docker run --rm "$tag" sh -c "test -f '$p'"; then
      log_success "Файл на месте: $p"
    else
      log_failure "Файл отсутствует: $p"
      TEST_FAILED=1
      return 1
    fi
  done
}

test_shcntx_not_empty() {
  log_header "Test :: shcntx files are non-trivial (не пустые)"

  local tag
  tag="$(resolve_image_tag)"

  local size
  size=$(docker run --rm "$tag" sh -c "stat -c %s /opt/1cv8/x86_64/${ONEC_VERSION}/shcntx_ru.hbk" 2>/dev/null || echo 0)

  if ! assert_gt "$size" 10000000 "shcntx_ru.hbk должен быть больше 10 МБ (реальный синтакс-помощник, не заглушка)"; then
    TEST_FAILED=1
    return 1
  fi
  log_success "Размер shcntx_ru.hbk: $size байт"
}

test_sonar_scanner_works() {
  log_header "Test :: sonar-scanner --version"

  local tag
  tag="$(resolve_image_tag)"

  local out
  out=$(docker run --rm "$tag" sonar-scanner --version 2>&1 | sed -n '1,10p' || true)

  if ! assert_contain "$out" "SonarScanner" "sonar-scanner должен отвечать на --version"; then
    TEST_FAILED=1
    return 1
  fi
  log_success "sonar-scanner работает"
}

# Run tests
test_hbk_files_present || true
test_shcntx_not_empty || true
test_sonar_scanner_works || true

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
