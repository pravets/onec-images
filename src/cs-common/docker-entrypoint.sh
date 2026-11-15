#!/bin/bash
# Общая точка входа образов cs-*.
#
# Контейнер стартует от root только для того, чтобы:
#   1) выставить права на смонтированные тома,
#   2) выполнить подготовку компонента (создание экземпляра и запись конфигурации
#      через утилиту ring — она пишет в /etc/1C/1CE и требует root),
# после чего процесс компонента запускается от непривилегированного пользователя.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

if [ "$(id -u)" = "0" ]; then
    mkdir -p "${CS_ROOT}"
    chown "${CS_USER}:${CS_USER}" "${CS_ROOT}"

    # Маркер готовности: снимается до подготовки и ставится после неё, чтобы
    # тесты и healthcheck не читали ещё не дописанную конфигурацию.
    rm -f "${CS_ROOT}/.prepared"

    for prepare in /usr/local/lib/cs/prepare.d/*.sh; do
        [ -e "${prepare}" ] || continue
        log "подготовка: $(basename "${prepare}")"
        "${prepare}"
    done

    touch "${CS_ROOT}/.prepared"
    chown "${CS_USER}:${CS_USER}" "${CS_ROOT}/.prepared"

    exec gosu "${CS_USER}" "$@"
fi

exec "$@"
