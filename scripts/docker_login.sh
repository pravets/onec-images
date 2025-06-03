#!/bin/bash

# Проверка наличия необходимых переменных среды
if [[ -z "$DOCKER_REGISTRY_URL" || -z "$DOCKER_LOGIN" || -z "$DOCKER_PASSWORD" ]]; then
    echo "Ошибка: Необходимо установить переменные среды DOCKER_REGISTRY_URL, DOCKER_LOGIN и DOCKER_PASSWORD."
    exit 1
fi

echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY_URL" -u "$DOCKER_LOGIN" --password-stdin

if [[ $? -eq 0 ]]; then
    echo "Успешная авторизация в $DOCKER_REGISTRY_URL"
else
    echo "Ошибка авторизации в $DOCKER_REGISTRY_URL"
    exit 1
fi