#!/bin/bash
# Общие функции для образов 1С:Сервера взаимодействия (cs-*).
#
# Подключается через `source`. Никаких побочных эффектов при подключении.
# Требует bash (используются массивы и /dev/tcp).

CS_PRODUCTS_HOME="${CS_PRODUCTS_HOME:-/opt/1C/1CE}"
CS_ROOT="${CS_ROOT:-/var/cs}"
CS_USER="${CS_USER:-cs}"
CS_HOME="${CS_HOME:-/home/cs}"

# ---------------------------------------------------------------------------
# Логирование
# ---------------------------------------------------------------------------

log()  { printf '[cs] %s\n' "$*" >&2; }
warn() { printf '[cs][WARN] %s\n' "$*" >&2; }
die()  { printf '[cs][ERROR] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Расположение компонентов
# ---------------------------------------------------------------------------

# component_dir <prefix> — каталог установленного компонента.
# Пример: component_dir 1c-cs-server-small-*
component_dir() {
    local pattern="$1" dir
    dir="$(ls -d "${CS_PRODUCTS_HOME}"/components/${pattern} 2>/dev/null | head -1 || true)"
    [ -n "$dir" ] || die "не найден компонент '${pattern}' в ${CS_PRODUCTS_HOME}/components"
    printf '%s\n' "${dir%/}"
}

component_launcher() {
    local dir
    dir="$(component_dir "$1")"
    [ -x "${dir}/bin/launcher" ] || die "не найден лаунчер в ${dir}/bin"
    printf '%s\n' "${dir}/bin/launcher"
}

# Экземпляры: имена и каталоги. Каталог инстанса — источник истины для лаунчера,
# имя нужно только утилите ring.
cs_instance_dir()          { printf '%s\n' "${CS_ROOT}/cs_instance"; }
hazelcast_instance_dir()   { printf '%s\n' "${CS_ROOT}/hazelcast_instance"; }
elasticsearch_instance_dir() { printf '%s\n' "${CS_ROOT}/elasticsearch_instance"; }

# ---------------------------------------------------------------------------
# Экземпляры компонентов
# ---------------------------------------------------------------------------

# ensure_instance <module> <name> <dir>
# Создаёт экземпляр, если его ещё нет. Идемпотентно, безопасно для томов.
ensure_instance() {
    local module="$1" name="$2" dir="$3"

    if [ -d "${dir}/config" ] && grep -qs "^${name}:" /etc/1C/1CE/server-instances.cfg; then
        log "экземпляр '${name}' уже создан (${dir})"
    else
        log "создаю экземпляр '${name}' (${module}) в ${dir}"
        mkdir -p "${dir}"
        chown "${CS_USER}:${CS_USER}" "${dir}"
        # ring печатает WARN про [getenforce]: в контейнере SELinux отсутствует,
        # на результат не влияет.
        ring "${module}" instance create \
            --dir "${dir}" \
            --name "${name}" \
            --owner "${CS_USER}" \
            || die "не удалось создать экземпляр '${name}'"
    fi

    mkdir -p "${dir}/logs" "${dir}/dumps"
    chown -R "${CS_USER}:${CS_USER}" "${dir}"
}

# ---------------------------------------------------------------------------
# Ожидание готовности зависимостей
# ---------------------------------------------------------------------------

# wait_for_tcp <host> <port> <timeout_sec> [interval_sec]
wait_for_tcp() {
    local host="$1" port="$2" timeout="${3:-60}" interval="${4:-2}" waited=0
    log "ожидаю ${host}:${port} (таймаут ${timeout}s)"
    while ! (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; do
        waited=$((waited + interval))
        if [ "${waited}" -ge "${timeout}" ]; then
            warn "не дождался ${host}:${port} за ${timeout}s"
            return 1
        fi
        sleep "${interval}"
    done
    exec 3>&- 2>/dev/null || true
    log "${host}:${port} доступен"
}

# wait_for_http <url> <timeout_sec> [expected_substring] [user] [password]
wait_for_http() {
    local url="$1" timeout="${2:-120}" expect="${3:-}" user="${4:-}" pass="${5:-}"
    local waited=0 body curl_auth=()

    [ -n "${user}" ] && curl_auth=(-u "${user}:${pass}")

    log "ожидаю HTTP ${url} (таймаут ${timeout}s)"
    while :; do
        if body="$(curl -fsS -m 5 "${curl_auth[@]}" "${url}" 2>/dev/null)"; then
            if [ -z "${expect}" ] || printf '%s' "${body}" | grep -q "${expect}"; then
                log "HTTP ${url} готов"
                return 0
            fi
        fi
        waited=$((waited + 2))
        if [ "${waited}" -ge "${timeout}" ]; then
            warn "не дождался ${url} за ${timeout}s"
            return 1
        fi
        sleep 2
    done
}

# ---------------------------------------------------------------------------
# JSON / HTTP для админ-REST CS
# ---------------------------------------------------------------------------

# cs_admin_post <path> <json>
cs_admin_post() {
    local path="$1" payload="$2"
    local base="http://127.0.0.1:${CS_ADMIN_PORT:-8087}"
    curl -Ssf -m 30 -X POST \
        -H 'Content-Type: application/json' \
        -u "${CS_ADMIN_USER:-admin}:${CS_ADMIN_PASSWORD:-admin}" \
        -d "${payload}" \
        "${base}${path}"
}

# cs_admin_get <path>
cs_admin_get() {
    local path="$1"
    local base="http://127.0.0.1:${CS_ADMIN_PORT:-8087}"
    curl -Ssf -m 30 \
        -u "${CS_ADMIN_USER:-admin}:${CS_ADMIN_PASSWORD:-admin}" \
        "${base}${path}"
}

# json_has_value <json> <needle> — есть ли подстрока (для идемпотентных проверок).
json_has_value() {
    printf '%s' "$1" | grep -qF -- "$2"
}
