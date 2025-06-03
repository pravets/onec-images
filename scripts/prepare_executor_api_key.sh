#!/bin/bash

# Проверяем, что переменная окружения установлена
if [ -z "$DEV1C_EXECUTOR_API_KEY" ]; then
    echo "Переменная среды DEV1C_EXECUTOR_API_KEY не установлена."
    exit 1
fi

# Записываем значение переменной в файл
echo -n "$DEV1C_EXECUTOR_API_KEY" > dev1c_executor_api_key.txt
echo "Ключ успешно записан в dev1c_executor_api_key.txt"