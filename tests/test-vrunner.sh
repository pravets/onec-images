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

# Resolve image tag from env or defaults (matches build-vrunner.sh scheme)
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
  echo "${prefix}vrunner:${ONEC_VERSION}${CI_SUFFIX:-}"
}

test_run_without_params() {
  log_header "Test :: vrunner run without params"

  local tag
  tag="$(resolve_image_tag)"

  # Run container and capture first lines of output to avoid hanging
  local out
  out=$(docker run --rm "$tag" 2>&1 | sed -n '1,20p' || true)

  # Basic checks — ensure binary identifies itself and prints commands list
  if assert_contain "$out" "vanessa-runner v" "Ожидается префикс версии vanessa-runner"; then : ; else exit 1; fi
  if assert_contain "$out" "Возможные команды:" "Ожидается список возможных команд"; then : ; else exit 1; fi
  if assert_contain "$out" "help" "Ожидается команда help в списке"; then : ; else exit 1; fi
  if assert_contain "$out" "version" "Ожидается команда version в списке"; then : ; else exit 1; fi
  if assert_contain "$out" "init-project" "Ожидается команда init-project в списке"; then : ; else exit 1; fi

  log_success "vrunner run without params test passed"
}

test_help_shows_commands() {
  log_header "Test :: vrunner --help shows commands"

  local tag
  tag="$(resolve_image_tag)"

  local out
  out=$(docker run --rm "$tag" --help 2>&1 | sed -n '1,50p' || true)

  if assert_contain "$out" "Возможные команды:" "--help должен содержать раздел 'Возможные команды'"; then : ; else exit 1; fi
  if assert_contain "$out" "init-dev" "--help должен перечислять init-dev"; then : ; else exit 1; fi

  log_success "vrunner --help test passed"
}

test_init_dev_ibcmd() {
  log_header "Test :: vrunner init-dev --ibcmd"

  local tag
  tag="$(resolve_image_tag)"

  # Run init-dev --ibcmd and capture output (limit lines)
  local out
  out=$(docker run --rm "$tag" init-dev --ibcmd 2>&1 | sed -n '1,200p' || true)

  # Expected substrings in the output
  if assert_contain "$out" "vanessa-runner v" "Ожидается префикс версии vanessa-runner"; then : ; else exit 1; fi
  if assert_contain "$out" "Используется ibcmd" "Должно сообщаться об использовании ibcmd"; then : ; else exit 1; fi
  if assert_contain "$out" "Создали базу данных" "Должно сообщаться о создании базы данных"; then : ; else exit 1; fi
  if assert_contain "$out" "/home/usr1cv8/build/ib" "Должен быть путь к созданной базе"; then : ; else exit 1; fi
  if assert_contain "$out" "Загрузка исходников не требуется" "Должно быть сообщение 'Загрузка исходников не требуется'"; then : ; else exit 1; fi
  if assert_contain "$out" "Инициализация завершена" "Должно быть сообщение об успешной инициализации"; then : ; else exit 1; fi

  log_success "vrunner init-dev --ibcmd test passed"
}

# Run tests
test_run_without_params
test_help_shows_commands
test_init_dev_ibcmd
