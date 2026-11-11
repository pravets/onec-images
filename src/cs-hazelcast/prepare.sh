#!/bin/bash
# Подготовка экземпляра Hazelcast.
#
# Значения по умолчанию из шаблона компонента уже подходят для одного узла:
# multicast выключен, tcp-ip включён, единственный участник — 127.0.0.1.
# Поэтому по умолчанию меняются только группа и пароль (они должны совпадать
# с hazelcast-параметрами самого CS, иначе клиент CS не попадёт в кластер).
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

CS_HAZELCAST_GROUP_NAME="${CS_HAZELCAST_GROUP_NAME:-1ce-cs}"
CS_HAZELCAST_GROUP_PASSWORD="${CS_HAZELCAST_GROUP_PASSWORD:-cs-pass}"
HC_INSTANCE_NAME="${CS_HAZELCAST_INSTANCE_NAME:-hazelcast}"

INSTANCE_DIR="$(hazelcast_instance_dir)"
ensure_instance hazelcast "${HC_INSTANCE_NAME}" "${INSTANCE_DIR}"

ring hazelcast --instance "${HC_INSTANCE_NAME}" set-params \
    --group-name "${CS_HAZELCAST_GROUP_NAME}" \
    --group-password "${CS_HAZELCAST_GROUP_PASSWORD}"

# Многоузловой режим: адреса должны быть разрешимы на момент настройки,
# иначе ring завершится с UnknownHostException.
if [ -n "${CS_HAZELCAST_MEMBERS:-}" ]; then
    log "включаю TCP/IP-обнаружение, участники: ${CS_HAZELCAST_MEMBERS}"
    ring hazelcast --instance "${HC_INSTANCE_NAME}" set-params \
        --multicast-enabled false \
        --tcp-ip-enabled true \
        --tcp-ip-members "${CS_HAZELCAST_MEMBERS}" \
        || warn "не удалось задать участников кластера Hazelcast (${CS_HAZELCAST_MEMBERS})"
fi

chown -R "${CS_USER}:${CS_USER}" "${INSTANCE_DIR}"
log "конфигурация Hazelcast готова: ${INSTANCE_DIR}/config"
