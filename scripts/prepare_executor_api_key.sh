#!/bin/bash

# Проверяем, что переменная окружения установлена
if [ -z "$DEV1C_EXECUTOR_API_KEY" ]; then
    echo "Переменная среды DEV1C_EXECUTOR_API_KEY не установлена."
    exit 1
fi

# Записываем значение переменной в файл
umask 077
set +x
echo -n "$DEV1C_EXECUTOR_API_KEY" > /tmp/dev1c_executor_api_key.txt
set -x
echo "Ключ успешно записан в /tmp/dev1c_executor_api_key.txt"