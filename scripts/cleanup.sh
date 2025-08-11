#!/usr/bin/env bash
set -euo pipefail

# Пропускаем очистку в среде CI
if [ -n "${CI:-}" ] && [ "${CI}" != "false" ]; then
    echo "Обнаружена среда CI: удаляем временные секреты и выходим из Docker."
    rm -f dev1c_executor_api_key.txt \
          /tmp/onec_username \
          /tmp/onec_password || true
    docker logout     || true
    exit 0
fi

# Удаление файла с ключом
rm -f dev1c_executor_api_key.txt
rm -f /tmp/onec_username
rm -f /tmp/onec_password

# Разлогинивание из Docker
if [ -n "${DOCKER_REGISTRY_URL:-}" ]; then
    docker logout "$DOCKER_REGISTRY_URL"
else
    docker logout
fi

# Очистка переменных среды из .env
if [ -f .env ]; then
    while IFS='=' read -r var _; do
        if [[ $var != "" && $var != \#* ]]; then
            unset "$var"
        fi
    done < .env
fi

echo "Cleanup complete."