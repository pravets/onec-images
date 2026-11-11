#!/bin/sh
# Формирует config.json клиента системы взаимодействия при старте контейнера.
#
# Руководство по установке (раздел 12) требует вручную править serverURL в
# config.json сайта внешних пользователей — здесь это делается из переменных
# окружения, поэтому образ не нужно пересобирать под каждый стенд.
#
# Запускается официальной точкой входа nginx из /docker-entrypoint.d/.
set -eu

SERVER_URL="${CS_PUBLIC_WS_URL:?переменная CS_PUBLIC_WS_URL обязательна (например wss://cs.example.com)}"
VAPID_KEY="${CS_VAPID_PUBLIC_KEY:-}"
SITE_ROOT="${CS_SITE_ROOT:-/usr/share/nginx/html}"
TARGET="${SITE_ROOT}/config.json"

if [ ! -d "${SITE_ROOT}" ]; then
    echo "[cs-site][ERROR] каталог статики не найден: ${SITE_ROOT}" >&2
    exit 1
fi

printf '{\n\t"serverURL": "%s",\n\t"VAPIDPublicKey": "%s"\n}\n' \
    "${SERVER_URL}" "${VAPID_KEY}" > "${TARGET}"
chmod 0644 "${TARGET}"

echo "[cs-site] config.json сформирован: serverURL=${SERVER_URL}"
