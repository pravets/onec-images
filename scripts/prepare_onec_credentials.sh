#!/bin/bash

# Проверяем, что переменная окружения установлена
if [ -z "$ONEC_USERNAME" ]; then
    echo "Переменная среды ONEC_USERNAME не установлена."
    exit 1
fi

# Записываем значение переменной в файл
umask 077
echo -n "$ONEC_USERNAME" > /tmp/onec_username
echo "Логин сайта релизов успешно записан в /tmp/onec_username"

# Проверяем, что переменная окружения установлена
if [ -z "$ONEC_PASSWORD" ]; then
    echo "Переменная среды ONEC_PASSWORD не установлена."
    exit 1
fi

# Записываем значение переменной в файл
umask 077
echo -n "$ONEC_PASSWORD" > /tmp/onec_password
echo "Пароль сайта релизов успешно записан в /tmp/onec_password"