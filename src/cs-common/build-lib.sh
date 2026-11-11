#!/bin/bash
# Общая логика build-скриптов семейства cs-*.
#
# Подключается из src/build-cs-*.sh, которые задают:
#   CS_IMAGE       — имя образа без реестра (cs-base, cs-server, ...)
#   CS_DOCKERFILE  — путь к Dockerfile относительно корня репозитория
#   CS_TEST        — путь к тесту относительно корня репозитория
#   CS_NEEDS_BASE  — true, если нужен базовый образ cs-base
#
# Дистрибутив CS скачивается стадией downloader внутри Dockerfile (yard, образ
# sleemp/onec-installer-downloader) — так же, как у платформы 1С и EDT.
# Учётные данные сайта релизов передаются BuildKit-секретами.

_cs_repo_root() { (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd); }

_cs_die() { printf '[build-cs][ERROR] %s\n' "$*" >&2; exit 1; }
_cs_log() { printf '[build-cs] %s\n' "$*"; }

_cs_require_version() {
    if [ -z "${CS_VERSION:-}" ]; then
        _cs_die "Переменная CS_VERSION не задана (например: CS_VERSION=30.0.42)"
    fi
    if ! [[ "${CS_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        _cs_die "CS_VERSION='${CS_VERSION}' не похожа на версию CS (ожидается X.Y.Z, например 30.0.42)"
    fi
}

# Определяет образ cs-base для производных образов:
# локальный без префикса -> локальный с префиксом -> pull из реестра -> локальная сборка.
_cs_resolve_base() {
    local root="$1" prefix="$2"
    local local_plain="cs-base:${CS_VERSION}"
    local local_prefixed="${prefix}cs-base:${CS_VERSION}"

    if docker image inspect "${local_plain}" > /dev/null 2>&1; then
        _cs_log "базовый образ найден локально: ${local_plain}"
        CS_BASE_IMAGE="${local_plain}"
    elif docker image inspect "${local_prefixed}" > /dev/null 2>&1; then
        _cs_log "базовый образ найден локально: ${local_prefixed}"
        CS_BASE_IMAGE="${local_prefixed}"
    elif [ -n "${DOCKER_REGISTRY_URL:-}" ] && [ "${DOCKER_REGISTRY_URL}" != "local" ]; then
        _cs_log "базовый образ не найден локально, пробую получить из реестра: ${local_prefixed}"
        if [ -n "${DOCKER_LOGIN:-}" ] && [ -n "${DOCKER_PASSWORD:-}" ]; then
            # shellcheck source=/dev/null
            source "${root}/scripts/docker_login.sh"
        fi
        if docker pull "${local_prefixed}"; then
            CS_BASE_IMAGE="${local_prefixed}"
        else
            _cs_log "не удалось получить из реестра, собираю cs-base локально"
            CS_BASE_IMAGE=""
        fi
    else
        CS_BASE_IMAGE=""
    fi

    if [ -z "${CS_BASE_IMAGE}" ]; then
        _cs_log "собираю базовый образ cs-base:${CS_VERSION}"
        PUSH_IMAGE="${PUSH_IMAGE}" CS_VERSION="${CS_VERSION}" \
            CI_SUFFIX="${CI_SUFFIX:-}" DOCKER_REGISTRY_URL="${DOCKER_REGISTRY_URL:-}" \
            "${root}/src/build-cs-base.sh"
        CS_BASE_IMAGE="${prefix}cs-base:${CS_VERSION}"
    fi
}

cs_build() {
    local root; root="$(_cs_repo_root)"
    : "${CS_IMAGE:?CS_IMAGE не задан}"
    : "${CS_DOCKERFILE:?CS_DOCKERFILE не задан}"
    : "${CS_TEST:?CS_TEST не задан}"
    CS_NEEDS_BASE="${CS_NEEDS_BASE:-false}"

    if [ -z "${CI:-}" ]; then
        echo "The script is not running in CI"
        # shellcheck source=/dev/null
        source "${root}/scripts/load_env.sh"
    else
        echo "The script is running in CI"
    fi

    # shellcheck source=/dev/null
    source "${root}/tools/assert.sh"

    _cs_require_version

    # Учётные данные сайта релизов нужны стадии downloader (yard).
    # shellcheck source=/dev/null
    source "${root}/scripts/prepare_onec_credentials.sh"

    PUSH_IMAGE="${PUSH_IMAGE:-true}"

    if [ "${DOCKER_SYSTEM_PRUNE:-}" = "true" ]; then
        docker system prune -af
    fi

    local prefix=""
    if [ -n "${DOCKER_REGISTRY_URL:-}" ]; then
        prefix="${DOCKER_REGISTRY_URL}/"
    fi
    local image_tag="${prefix}${CS_IMAGE}:${CS_VERSION}${CI_SUFFIX:-}"
    _cs_log "версия CS: ${CS_VERSION}"

    CS_BASE_IMAGE=""
    if [ "${CS_NEEDS_BASE}" = "true" ]; then
        _cs_resolve_base "${root}" "${prefix}"
    fi

    if [ "${PUSH_IMAGE}" = "true" ]; then
        # shellcheck source=/dev/null
        source "${root}/scripts/docker_login.sh"
    fi

    local -a build_args=(
        --secret "id=onec_username,src=/tmp/onec_username"
        --secret "id=onec_password,src=/tmp/onec_password"
        --build-arg "CS_VERSION=${CS_VERSION}"
        --build-arg "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    )
    # --pull только для образов без локальной базы: иначе BuildKit пытается
    # получить локальный cs-base (например, local/cs-base) из реестра.
    if [ -z "${CS_BASE_IMAGE}" ]; then
        build_args+=(--pull)
    fi
    if [ -n "${CS_BASE_IMAGE}" ]; then
        build_args+=(--build-arg "CS_BASE_IMAGE=${CS_BASE_IMAGE}")
    fi
    # Фильтры yard переопределяются только когда заданы — иначе действуют
    # значения по умолчанию из Dockerfile.
    if [ -n "${CS_YARD_APP_FILTER:-}" ]; then
        build_args+=(--build-arg "CS_YARD_APP_FILTER=${CS_YARD_APP_FILTER}")
    fi
    if [ -n "${CS_YARD_DISTR_FILTER:-}" ]; then
        build_args+=(--build-arg "CS_YARD_DISTR_FILTER=${CS_YARD_DISTR_FILTER}")
    fi

    local -a context_arg=(.)
    if [ "${NO_CACHE:-}" = "true" ]; then
        context_arg=(--no-cache .)
    fi

    _cs_log "сборка ${image_tag}"
    DOCKER_BUILDKIT=1 docker build \
        "${build_args[@]}" \
        -t "${image_tag}" \
        -f "${root}/${CS_DOCKERFILE}" \
        "${context_arg[@]}"

    local test_path="${root}/${CS_TEST}"
    if [ ! -x "${test_path}" ]; then
        log_failure "не найден исполняемый тест: ${test_path}"
        # shellcheck source=/dev/null
        source "${root}/scripts/cleanup.sh"
        exit 1
    fi

    # CI=true заставляет тест возвращать код провала и вне CI-окружения.
    if CI=true IMAGE_TAG="${image_tag}" CS_VERSION="${CS_VERSION}" CS_IMAGE="${CS_IMAGE}" "${test_path}"; then
        if [ "${PUSH_IMAGE}" = "true" ]; then
            docker push "${image_tag}"
        else
            echo "Skipping push (PUSH_IMAGE=false)"
        fi
        # shellcheck source=/dev/null
        source "${root}/scripts/cleanup.sh"
    else
        log_failure "ERROR: Tests failed. Docker image will not be pushed."
        # shellcheck source=/dev/null
        source "${root}/scripts/cleanup.sh"
        exit 1
    fi
}
