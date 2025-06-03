#!/bin/bash

# Удаление файла с ключом
rm -f dev1c_executor_api_key.txt

# Разлогинивание из Docker
if [ -n "$DOCKER_REGISTRY_URL" ]; then
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