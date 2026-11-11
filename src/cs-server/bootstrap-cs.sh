#!/bin/bash
# Идемпотентная регистрация внешних зависимостей в 1С:Сервере взаимодействия.
#
# Работает только по административному REST API (порт 8087) и запускается
# отдельным одноразовым контейнером после того, как CS поднялся.
# Утилита ring здесь не используется: она требует root и не нужна для HTTP-вызовов.
#
# Режимы (CS_BOOTSTRAP): once — только если маркера нет (по умолчанию),
# always — выполнять при каждом запуске, never — ничего не делать.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

CS_ADMIN_HOST="${CS_ADMIN_HOST:-127.0.0.1}"
CS_ADMIN_PORT="${CS_ADMIN_PORT:-8087}"
CS_ADMIN_USER="${CS_ADMIN_USER:-admin}"
CS_ADMIN_PASSWORD="${CS_ADMIN_PASSWORD:-admin}"
CS_BOOTSTRAP="${CS_BOOTSTRAP:-once}"
CS_BOOTSTRAP_STRICT="${CS_BOOTSTRAP_STRICT:-false}"
BOOTSTRAP_FAILED=0

MARKER="${CS_ROOT}/cs_instance/.bootstrap-done"

case "${CS_BOOTSTRAP}" in
    never)
        log "CS_BOOTSTRAP=never — регистрация пропущена"
        exit 0
        ;;
    once)
        if [ -f "${MARKER}" ]; then
            log "регистрация уже выполнялась ранее (${MARKER})"
            exit 0
        fi
        ;;
    always)
        log "CS_BOOTSTRAP=always — регистрация выполняется при каждом запуске"
        ;;
    *)
        die "недопустимое значение CS_BOOTSTRAP='${CS_BOOTSTRAP}' (once|always|never)"
        ;;
esac

# Уровень ошибок: строгий режим валит контейнер, мягкий — только предупреждает.
# В мягком режиме маркер не выставляется, чтобы регистрация повторилась.
on_error() {
    BOOTSTRAP_FAILED=1
    if [ "${CS_BOOTSTRAP_STRICT}" = "true" ]; then
        die "$1"
    fi
    warn "$1 (продолжаю, CS_BOOTSTRAP_STRICT=false)"
}

# register <path> <needle> <payload> <описание>
register() {
    local path="$1" needle="$2" payload="$3" label="$4" existing

    if existing="$(cs_admin_get "${path}" 2>/dev/null)"; then
        if json_has_value "${existing}" "${needle}"; then
            log "${label}: уже зарегистрировано, пропускаю"
            return 0
        fi
    fi

    if cs_admin_post "${path}" "${payload}" >/dev/null; then
        log "${label}: зарегистрировано"
    else
        on_error "${label}: регистрация через ${path} не удалась"
    fi
}

log "ожидаю административный REST CS на $(cs_admin_host):${CS_ADMIN_PORT}"
if ! wait_for_http "$(cs_admin_base)/rs/health" "${CS_BOOTSTRAP_TIMEOUT:-300}"; then
    die "административный REST CS недоступен — регистрация невозможна"
fi

# ---------------------------------------------------------------------------
# 1. Основная база данных (внешняя PostgreSQL 15)
# ---------------------------------------------------------------------------
if [ -n "${CS_DB_URL:-}" ]; then
    : "${CS_DB_USER:?CS_DB_USER обязателен при заданном CS_DB_URL}"
    : "${CS_DB_PASSWORD:?CS_DB_PASSWORD обязателен при заданном CS_DB_URL}"
    register /admin/bucket_server "${CS_DB_URL}" \
        "{\"url\":\"$(json_escape "${CS_DB_URL}")\",\"username\":\"$(json_escape "${CS_DB_USER}")\",\"password\":\"$(json_escape "${CS_DB_PASSWORD}")\",\"enabled\":true}" \
        "основная БД"
else
    warn "CS_DB_URL не задан — основная БД не регистрируется"
fi

# ---------------------------------------------------------------------------
# 2. Объектное хранилище S3 (внешний S3 или контейнер RustFS)
# ---------------------------------------------------------------------------
if [ -n "${CS_S3_ENDPOINT:-}" ]; then
    : "${CS_S3_ACCESS_KEY:?CS_S3_ACCESS_KEY обязателен при заданном CS_S3_ENDPOINT}"
    : "${CS_S3_SECRET_KEY:?CS_S3_SECRET_KEY обязателен при заданном CS_S3_ENDPOINT}"
    s3_bucket="${CS_S3_BUCKET:-cs-bucket}"
    s3_region="${CS_S3_REGION:-eu-west-1}"
    s3_signature="${CS_S3_SIGNATURE_VERSION:-V4}"
    s3_limit="${CS_S3_FILE_SIZE_LIMIT:-1073741824}"
    s3_days="${CS_S3_DAYS_TO_KEEP:-31}"
    register /admin/storage_server "${s3_bucket}" \
        "{\"apiType\":\"AMAZON\",\"storageType\":\"DEFAULT\",\"baseUrl\":\"$(json_escape "${CS_S3_ENDPOINT}")\",\"containerUrl\":\"$(json_escape "${CS_S3_ENDPOINT}/${s3_bucket}")\",\"containerName\":\"$(json_escape "${s3_bucket}")\",\"region\":\"$(json_escape "${s3_region}")\",\"accessKeyId\":\"$(json_escape "${CS_S3_ACCESS_KEY}")\",\"secretKey\":\"$(json_escape "${CS_S3_SECRET_KEY}")\",\"signatureVersion\":\"$(json_escape "${s3_signature}")\",\"uploadLimit\":${s3_limit},\"downloadLimit\":${s3_limit},\"fileSizeLimit\":${s3_limit},\"bytesToKeep\":0,\"daysToKeep\":${s3_days},\"pathStyleAccessEnabled\":true}" \
        "S3-хранилище (${CS_S3_ENDPOINT}/${s3_bucket})"
else
    log "CS_S3_ENDPOINT не задан — S3-хранилище не регистрируется"
fi

# ---------------------------------------------------------------------------
# 3. Медиасервер Janus (внешний)
# ---------------------------------------------------------------------------
if [ -n "${CS_MEDIA_SERVER_URL:-}" ]; then
    register /admin/media_server "${CS_MEDIA_SERVER_URL}" \
        "{\"url\":\"$(json_escape "${CS_MEDIA_SERVER_URL}")\",\"name\":\"$(json_escape "${CS_MEDIA_SERVER_NAME:-Janus 1}")\",\"confereeLimit\":${CS_MEDIA_CONFEREE_LIMIT:-1000},\"enabled\":true}" \
        "медиасервер ${CS_MEDIA_SERVER_URL}"
else
    log "CS_MEDIA_SERVER_URL не задан — видеосвязь не подключена"
fi

# ---------------------------------------------------------------------------
# 4. TURN/STUN для медиасоединений (внешний coturn)
# ---------------------------------------------------------------------------
if [ -n "${CS_TURN_URL:-}" ]; then
    register /admin/bucket_server "${CS_TURN_URL}" \
        "{\"url\":\"$(json_escape "${CS_TURN_URL}")\",\"username\":\"$(json_escape "${CS_TURN_USER:-}")\",\"password\":\"$(json_escape "${CS_TURN_PASSWORD:-}")\",\"enabled\":true}" \
        "TURN/STUN ${CS_TURN_URL}"
else
    log "CS_TURN_URL не задан — TURN/STUN не регистрируется"
fi

# ---------------------------------------------------------------------------
# 5. Проверка итогового состояния (не фатальна: часть подсистем может быть отключена)
# ---------------------------------------------------------------------------
if health="$(cs_admin_get /rs/health 2>/dev/null)"; then
    log "состояние CS: ${health}"
    if ! json_has_value "${health}" '"mainDbOk":true'; then
        on_error "CS сообщает, что основная БД недоступна (mainDbOk ≠ true)"
    fi
else
    on_error "не удалось прочитать /rs/health"
fi

if [ "${BOOTSTRAP_FAILED}" -ne 0 ]; then
    warn "регистрация завершена с ошибками — маркер не выставлен, повтор при следующем запуске"
    exit 0
fi

mkdir -p "$(dirname "${MARKER}")"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "${MARKER}" 2>/dev/null || true
log "регистрация завершена"
