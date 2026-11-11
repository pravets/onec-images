#!/bin/bash
# Подготовка экземпляра Elasticsearch.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

CS_ES_CLUSTER_NAME="${CS_ES_CLUSTER_NAME:-1ce-cs}"
CS_ES_NODE_NAME="${CS_ES_NODE_NAME:-node-1}"
ES_INSTANCE_NAME="${CS_ES_INSTANCE_NAME:-elasticsearch}"

INSTANCE_DIR="$(elasticsearch_instance_dir)"
CONFIG_FILE="${INSTANCE_DIR}/config/elasticsearch.yml"

ensure_instance elasticsearch "${ES_INSTANCE_NAME}" "${INSTANCE_DIR}"

ring elasticsearch --instance "${ES_INSTANCE_NAME}" set-params \
    --cluster-name "${CS_ES_CLUSTER_NAME}" \
    --node-name "${CS_ES_NODE_NAME}"

# Многоузловой режим: host:port, список через запятую.
if [ -n "${CS_ES_DISCOVERY_HOSTS:-}" ]; then
    IFS=',' read -r -a hosts <<< "${CS_ES_DISCOVERY_HOSTS}"
    for host in "${hosts[@]}"; do
        [ -n "${host}" ] || continue
        ring elasticsearch --instance "${ES_INSTANCE_NAME}" discovery add-host "${host}" \
            || warn "не удалось добавить узел Elasticsearch ${host}"
    done
fi

# Каталоги данных и логов: по умолчанию Elasticsearch пишет внутрь каталога
# компонента, который принадлежит root и недоступен пользователю cs.
mkdir -p "${INSTANCE_DIR}/data" "${INSTANCE_DIR}/logs" "${INSTANCE_DIR}/dumps"

# path.* и настройка проверки системных вызовов задаются напрямую в конфигурации
# Elasticsearch: у ring нет для них параметров. ring перезаписывает файл при
# set-params, поэтому правки добавляются после него и только один раз.
if ! grep -q '^path.data:' "${CONFIG_FILE}" 2>/dev/null; then
    {
        echo "path.data: ${INSTANCE_DIR}/data"
        echo "path.logs: ${INSTANCE_DIR}/logs"
    } >> "${CONFIG_FILE}"
    log "в ${CONFIG_FILE} заданы path.data и path.logs"
fi

# По умолчанию компонент слушает только 127.0.0.1 — в контейнере это делает его
# недоступным ни для CS из соседнего контейнера, ни для внешних инструментов.
if ! grep -q '^network.host:' "${CONFIG_FILE}" 2>/dev/null; then
    echo "network.host: ${CS_ES_NETWORK_HOST:-0.0.0.0}" >> "${CONFIG_FILE}"
    log "в ${CONFIG_FILE} задан network.host"
fi

# В контейнере проверка фильтра системных вызовов обычно недоступна,
# поэтому по умолчанию она отключена (включается CS_ES_SYSTEM_CALL_FILTER=true).
if ! grep -q '^bootstrap.system_call_filter:' "${CONFIG_FILE}" 2>/dev/null; then
    echo "bootstrap.system_call_filter: ${CS_ES_SYSTEM_CALL_FILTER:-false}" >> "${CONFIG_FILE}"
fi

chown -R "${CS_USER}:${CS_USER}" "${INSTANCE_DIR}"
log "конфигурация Elasticsearch готова: ${CONFIG_FILE}"
