#!/bin/bash
# Подготовка экземпляра 1С:Сервера взаимодействия.
#
# Выполняется от root до запуска лаунчера: создаёт экземпляр и записывает всю
# конфигурацию из переменных окружения. Всё, что умеет утилита ring, задаётся
# через неё (так же, как в руководстве по установке); файлами пишется только то,
# для чего у ring нет команды (http_security, video, logging).
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

: "${CS_DB_URL:?переменная CS_DB_URL обязательна (JDBC-строка внешней PostgreSQL 15)}"
: "${CS_DB_USER:?переменная CS_DB_USER обязательна}"
: "${CS_DB_PASSWORD:?переменная CS_DB_PASSWORD обязательна}"

CS_INSTANCE_NAME="${CS_INSTANCE_NAME:-cs}"
CS_WS_HOSTNAME="${CS_WS_HOSTNAME:-0.0.0.0}"
CS_WS_PORT="${CS_WS_PORT:-8086}"
CS_WS_WSS="${CS_WS_WSS:-false}"
CS_ADMIN_ADDRESS="${CS_ADMIN_ADDRESS:-0.0.0.0}"
CS_ADMIN_PORT="${CS_ADMIN_PORT:-8087}"
CS_ADMIN_USER="${CS_ADMIN_USER:-admin}"
CS_ADMIN_PASSWORD="${CS_ADMIN_PASSWORD:-admin}"
CS_METRIC_USER="${CS_METRIC_USER:-prometheus}"
CS_METRIC_PASSWORD="${CS_METRIC_PASSWORD:-prometheus}"
CS_INTEGRATION_PORT="${CS_INTEGRATION_PORT:-8443}"
CS_CONFERENCE_ADDRESS="${CS_CONFERENCE_ADDRESS:-0.0.0.0}"
CS_CONFERENCE_PORT="${CS_CONFERENCE_PORT:-8444}"
CS_ES_ADDRESSES="${CS_ES_ADDRESSES:-elasticsearch:9300}"
CS_ES_CLUSTER_NAME="${CS_ES_CLUSTER_NAME:-1ce-cs}"
CS_HAZELCAST_ADDRESSES="${CS_HAZELCAST_ADDRESSES:-hazelcast}"
CS_HAZELCAST_GROUP_NAME="${CS_HAZELCAST_GROUP_NAME:-1ce-cs}"
CS_HAZELCAST_GROUP_PASSWORD="${CS_HAZELCAST_GROUP_PASSWORD:-cs-pass}"
CS_VIDEO_ENABLED="${CS_VIDEO_ENABLED:-false}"
CS_LOG_CONSOLE="${CS_LOG_CONSOLE:-true}"
CS_LOG_LEVEL="${CS_LOG_LEVEL:-WARN}"

INSTANCE_DIR="$(cs_instance_dir)"
CONFIG_DIR="${INSTANCE_DIR}/config"

# yaml_quote <значение> — безопасная строка YAML в одинарных кавычках.
yaml_quote() {
    local value="$1"
    value="${value//\'/\'\'}"
    printf "'%s'" "${value}"
}

ensure_instance cs "${CS_INSTANCE_NAME}" "${INSTANCE_DIR}"
mkdir -p "${CONFIG_DIR}"

ring_cs() { ring cs --instance "${CS_INSTANCE_NAME}" "$@"; }

# ---------------------------------------------------------------------------
# WebSocket: порт, на котором клиенты 1С подключаются к серверу взаимодействия
# ---------------------------------------------------------------------------
ring_cs websocket set-params \
    --hostname "${CS_WS_HOSTNAME}" \
    --port "${CS_WS_PORT}" \
    --wss "${CS_WS_WSS}"
if [ -n "${CS_WS_KEYSTORE_PATH:-}" ]; then
    ring_cs websocket set-params \
        --keystore-path "${CS_WS_KEYSTORE_PATH}" \
        --keystore-password "${CS_WS_KEYSTORE_PASSWORD:-}" \
        --keystore-format "${CS_WS_KEYSTORE_FORMAT:-JKS}"
fi

# ---------------------------------------------------------------------------
# Административный REST (по умолчанию слушает только 127.0.0.1 — в контейнере
# это делает его недоступным, поэтому адрес задаётся явно)
# ---------------------------------------------------------------------------
ring_cs maintenance set-params \
    --address "${CS_ADMIN_ADDRESS}" \
    --port "${CS_ADMIN_PORT}"

# ---------------------------------------------------------------------------
# Интеграционный endpoint и endpoint конференций
# ---------------------------------------------------------------------------
ring_cs integration set-params --port "${CS_INTEGRATION_PORT}"
if [ -n "${CS_INTEGRATION_PUBLIC_URL:-}" ]; then
    ring_cs integration set-params --public-url "${CS_INTEGRATION_PUBLIC_URL}"
fi

ring_cs conference_endpoint set-params \
    --address "${CS_CONFERENCE_ADDRESS}" \
    --port "${CS_CONFERENCE_PORT}"

# ---------------------------------------------------------------------------
# Elasticsearch и Hazelcast: либо имена контейнеров стека, либо внешние адреса
# ---------------------------------------------------------------------------
ring_cs elasticsearch set-params \
    --addresses "${CS_ES_ADDRESSES}" \
    --cluster-name "${CS_ES_CLUSTER_NAME}"

ring_cs hazelcast set-params \
    --addresses "${CS_HAZELCAST_ADDRESSES}" \
    --group-name "${CS_HAZELCAST_GROUP_NAME}" \
    --group-password "${CS_HAZELCAST_GROUP_PASSWORD}"

# ---------------------------------------------------------------------------
# PostgreSQL: пулы common и privileged
# ---------------------------------------------------------------------------
for pool in common privileged; do
    ring_cs jdbc pools --name "${pool}" set-params \
        --url "${CS_DB_URL}" \
        --username "${CS_DB_USER}" \
        --password "${CS_DB_PASSWORD}"
done

# ---------------------------------------------------------------------------
# Сайт внешних пользователей (нужен для приглашения внешних участников)
# ---------------------------------------------------------------------------
if [ -n "${CS_PUBLIC_URL:-}" ]; then
    ring_cs site set-params --public-url "${CS_PUBLIC_URL}"
fi

# ---------------------------------------------------------------------------
# Учётные записи административного REST.
# Отдельной команды ring нет — файл пишется напрямую по шаблону компонента.
# ---------------------------------------------------------------------------
cat > "${CONFIG_DIR}/http_security.yml" <<EOF
http_security:
  users:
    - name: $(yaml_quote "${CS_ADMIN_USER}")
      password: $(yaml_quote "${CS_ADMIN_PASSWORD}")
      role: ADMIN
  metric-agent:
    name: $(yaml_quote "${CS_METRIC_USER}")
    password: $(yaml_quote "${CS_METRIC_PASSWORD}")
    role: PROMETHEUS_ADMIN
EOF
log "записан http_security.yml (пользователь ${CS_ADMIN_USER})"

# ---------------------------------------------------------------------------
# Видеоконференции (см. руководство, раздел 10.3). Файл читается при старте CS.
# ---------------------------------------------------------------------------
if [ "${CS_VIDEO_ENABLED}" = "true" ]; then
    cat > "${CONFIG_DIR}/video.yml" <<EOF
video:
  enabled: true
  conference-server-based-member-limit: ${CS_VIDEO_MEMBER_LIMIT:-34}
  conference-server-based-threshold: ${CS_VIDEO_SERVER_THRESHOLD:-3}
  max-bandwidth: ${CS_VIDEO_MAX_BANDWIDTH:-2000}
  max-reference-width: ${CS_VIDEO_MAX_WIDTH:-1280}
  max-reference-height: ${CS_VIDEO_MAX_HEIGHT:-720}
  max-reference-fps: ${CS_VIDEO_MAX_FPS:-30}
EOF
    log "записан video.yml (видеоконференции включены)"
fi

# ---------------------------------------------------------------------------
# Логи: по умолчанию CS пишет только в файлы экземпляра. Добавляем консольный
# обработчик, чтобы логи были видны в `docker logs`.
# ---------------------------------------------------------------------------
if [ "${CS_LOG_CONSOLE}" = "true" ]; then
    cat > "${CONFIG_DIR}/logging.yml" <<EOF
logging:
  handlers:
    - type: console
      name: console
      level: ${CS_LOG_LEVEL}
      format: TECHLOG
      encoding: UTF-8
    - type: file
      name: file
      level: TRACE
      format: TECHLOG
      encoding: UTF-8
      file: \${instance.root}/logs/server.log
      limit: 10000000
      count: 10
      queue-capacity: 1000
    - type: file
      name: websocket-file
      level: WARN
      format: TECHLOG
      encoding: UTF-8
      file: \${instance.root}/logs/websocket.log
      limit: 10000000
      count: 10
      queue-capacity: 1000
  loggers:
    - name: ROOT
      level: ${CS_LOG_LEVEL}
      use-parent-handlers: false
      handlers:
        - file
        - console
    - name: com.corundumstudio.socketio.handler.InPacketHandler
      level: WARN
      use-parent-handlers: false
      handlers:
        - websocket-file
    - name: com.corundumstudio.socketio.handler.EncoderHandler
      level: WARN
      use-parent-handlers: false
      handlers:
        - websocket-file
EOF
    log "записан logging.yml (консольный обработчик, уровень ${CS_LOG_LEVEL})"
fi

# ring пишет конфигурацию от root — возвращаем владельца,
# чтобы лаунчер мог писать логи и дампы от пользователя cs.
chown -R "${CS_USER}:${CS_USER}" "${INSTANCE_DIR}"
log "конфигурация CS готова: ${CONFIG_DIR}"
