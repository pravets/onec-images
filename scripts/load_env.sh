#!/bin/bash

# Путь к .env файлу (по умолчанию в текущей директории)
ENV_FILE=".env"

# Проверяем, существует ли файл
if [ ! -f "$ENV_FILE" ]; then
    echo "Файл $ENV_FILE не найден."
    exit 1
fi

# Загружаем переменные окружения из .env файла
set -a
source "$ENV_FILE"
set +a

echo "Переменные окружения загружены из $ENV_FILE"