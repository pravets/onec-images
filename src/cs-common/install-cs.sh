#!/bin/bash
# Установка 1С:Сервера взаимодействия из дистрибутива.
#
# Аргумент — файл 1c_cs_*.tar.gz либо каталог, в котором он лежит.
# Ставится полный продукт (cs, hazelcast, elasticsearch, site, web-chat) —
# так же, как это делает штатный 1ce-installer-cli из руководства по установке.
set -euo pipefail

SOURCE="${1:?использование: install-cs.sh <файл 1c_cs_*.tar.gz | каталог с ним>}"
WORK_DIR="${2:-/tmp/cs-distrib}"

if [ -d "${SOURCE}" ]; then
    TARBALL="$(ls "${SOURCE}"/1c_cs_*_linux_x86_64.tar.gz 2>/dev/null | head -1 || true)"
    [ -n "${TARBALL}" ] || {
        printf '[install-cs][ERROR] в каталоге %s нет архива 1c_cs_*_linux_x86_64.tar.gz\n' "${SOURCE}" >&2
        exit 1
    }
else
    TARBALL="${SOURCE}"
fi

[ -f "${TARBALL}" ] || {
    printf '[install-cs][ERROR] не найден дистрибутив: %s\n' "${TARBALL}" >&2
    exit 1
}

printf '[install-cs] распаковка %s\n' "$(basename "${TARBALL}")" >&2
mkdir -p "${WORK_DIR}"
tar -xzf "${TARBALL}" -C "${WORK_DIR}"

if [ ! -x "${WORK_DIR}/1ce-installer-cli" ]; then
    printf '[install-cs][ERROR] в дистрибутиве нет исполняемого 1ce-installer-cli\n' >&2
    exit 1
fi

printf '[install-cs] установка продукта\n' >&2
cd "${WORK_DIR}"
# --ignore-signature-warnings: дистрибутив с сайта релизов не подписан для нас.
# --ignore-hardware-checks: контейнер не проходит проверки оборудования (CPU/RAM).
./1ce-installer-cli install \
    --ignore-signature-warnings \
    --ignore-hardware-checks

cd /
rm -rf "${WORK_DIR}"

# Стабильный путь к ring независимо от версии компонента.
# Символьную ссылку использовать нельзя: запускающий скрипт ring вычисляет путь
# к своим модулям как dirname "$0", поэтому через ссылку теряет lib/boot.
RING_DIR="$(ls -d /opt/1C/1CE/components/1c-enterprise-ring-*/ 2>/dev/null | head -1 || true)"
if [ -z "${RING_DIR}" ]; then
    printf '[install-cs][ERROR] компонент ring не установлен\n' >&2
    exit 1
fi
RING_BIN="${RING_DIR%/}/ring"
cat > /usr/local/bin/ring <<EOF
#!/bin/sh
exec "${RING_BIN}" "\$@"
EOF
chmod +x /usr/local/bin/ring

RING_VERSION="$(ring --version)"
if [ -z "${RING_VERSION}" ]; then
    printf '[install-cs][ERROR] утилита ring не запускается\n' >&2
    exit 1
fi
printf '[install-cs] версия ring: %s\n' "${RING_VERSION}" >&2
