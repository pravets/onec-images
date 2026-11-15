#!/bin/bash
# Запуск компонента CS в foreground от текущего пользователя.
#
# Использование: run-component.sh <маска каталога компонента> <каталог экземпляра>
# Пример:        run-component.sh '1c-cs-server-small-*' /var/cs/cs_instance
#
# systemd не используется: утилита ring умеет только создавать юниты systemd,
# поэтому компонент запускается напрямую его же лаунчером (см. launcher.yml).
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

COMPONENT_PATTERN="${1:?не передан шаблон каталога компонента}"
INSTANCE_DIR="${2:?не передан каталог экземпляра}"

LAUNCHER="$(component_launcher "${COMPONENT_PATTERN}")"
COMPONENT_DIR="$(dirname "$(dirname "${LAUNCHER}")")"

[ -d "${INSTANCE_DIR}/config" ] || die "экземпляр не подготовлен: ${INSTANCE_DIR}/config отсутствует"

log "запуск компонента ${COMPONENT_PATTERN} (экземпляр ${INSTANCE_DIR})"
cd "${COMPONENT_DIR}"
exec "${LAUNCHER}" start --instance "${INSTANCE_DIR}"
