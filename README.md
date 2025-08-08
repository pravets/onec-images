# onec-images

![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/pravets/onec-images?utm_source=oss&utm_medium=github&utm_campaign=pravets%2Fonec-images&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)
![License](https://img.shields.io/github/license/pravets/oscript-images)
[![Telegram](https://telegram-badge.vercel.app/api/telegram-badge?channelId=@pravets_IT)](https://t.me/pravets_it)

Всё необходимое для сборки docker-образов с платформой 1С и сопутствующими инструментами.

## Оглавление

- [Как собрать образы](#как-собрать-образы)
    - [Сборка через GitHub Actions](#сборка-через-github-actions)
    - [Локальная сборка](#локальная-сборка)
- [1С:Исполнитель](#1сисполнитель)
- [1С:EDT](#1сedt)

## Как собрать образы

У вас есть 2 способа для сборки необходимых вам образов:

1. С помощью форка данного репозитория и сборки через [GitHub Actions](#сборка-через-github-actions) (предпочтительный вариант).
2. Клонирование и [локальная сборка](#локальная-сборка) на вашем компьютере. Сборка возможна только на ПК с ОС Linux.

[↑ Наверх](#onec-images)

### Сборка через GitHub Actions

1. Форкаем этот репозиторий.
2. Включаем GitHub Actions, если не включилось автоматически.
3. Пробрасываем в GitHub Actions необходимые секреты. В общем случае это:
    - `DOCKER_REGISTRY_URL` — адрес вашего приватного docker registry, куда будут запушены собранные образы.
    - `DOCKER_LOGIN` — логин для вашего registry.
    - `DOCKER_PASSWORD` — пароль для вашего registry.
4. Для образов, установщики, которых требуется скачать с сайта релизов также требуются:
    - `ONEC_USERNAME` — логин к сайту релизов 1С.
    - `ONEC_PASSWORD` — пароль к сайту релизов 1С.

5. "Навешиваем" нужные теги для триггера сборки. Если теги уже есть, предварительно их удаляем или пушим теги с --force. Теги можно "навешивать" на последний коммит или на последний релиз необходимого для сборки образа.
6. После завершения сборки получаем готовые образы в вашем registry.

[↑ Наверх](#onec-images)

### Локальная сборка

1. Клонируем репозиторий.
2. Копируем файл `.env.example` в `.env`.
3. Заполняем необходимые для сборки переменные среды в файле `.env`.
4. Запускаем скрипты для сборки нужных образов. Скрипты лежат в директории `src` и имеют имя вида `build-ОбразДляСборки.sh`.

[↑ Наверх](#onec-images)

## 1С:Исполнитель

Для сборки требуется также ключ API для скачивания установщика 1С:Исполнителя с сайта https://developer.1c.ru. Ключ необходимо записать в переменную среды/секрет `DEV1C_EXECUTOR_API_KEY`.

- Триггером для сборки в Actions является тег вида `executor_ВерсияДляСборки`, например `executor_3.0.2.2`.
- Для PR‑проверок добавлен workflow, который собирает и тестирует образ без публикации.

- Локальная сборка:
  1. Заполните `.env` значениями `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD`, `DEV1C_EXECUTOR_API_KEY`.
  2. Укажите версию Executor:
     - однократно в текущей сессии: `export EXECUTOR_VERSION=3.0.2.2`
     - либо инлайном при запуске: `EXECUTOR_VERSION=3.0.2.2 ./src/build-executor.sh`
  3. Запустите сборку: `./src/build-executor.sh`.

  - без публикации в реестр (локальная проверка):
    - один запуск: `PUSH_IMAGE=false EXECUTOR_VERSION=3.0.2.2 ./src/build-executor.sh`
    - либо через `.env`: `PUSH_IMAGE=false`

- Результат локальной сборки — образ с тегом `$DOCKER_REGISTRY_URL/executor:$EXECUTOR_VERSION`.

[↑ Наверх](#onec-images)

## 1С:EDT

Для сборки требуется доступ к сайту релизов 1С для скачивания установщика EDT. Данные учётной записи необходимо передать через переменные среды/секреты `ONEC_USERNAME` и `ONEC_PASSWORD`.

- В GitHub Actions, помимо общих секретов `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD`, добавьте:
  - `ONEC_USERNAME` — логин к сайту релизов 1С.
  - `ONEC_PASSWORD` — пароль к сайту релизов 1С.

- Триггер для сборки в Actions — тег вида `edt_ВерсияEDT`, например `edt_2024.1.3`.

- Локальная сборка:
  1. Заполните `.env` значениями `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD`, `ONEC_USERNAME`, `ONEC_PASSWORD`.
  2. Укажите версию EDT (поддерживаются мажорные версии 2023 и 2024; версии ниже 2023 не поддерживаются, так как начиная с 2023 появилась `1cedtcli` и была упразднена `ring`):
     - однократно в текущей сессии: `export EDT_VERSION=2024.1.3`
     - либо инлайном при запуске: `EDT_VERSION=2024.1.3 ./src/build-edt.sh`
  3. Запустите сборку: `./src/build-edt.sh`.

- Результат локальной сборки — образ с тегом `$DOCKER_REGISTRY_URL/edt:$EDT_VERSION`.

- Полезно знать:
  - Переменная `NO_CACHE=true` отключит кэш сборки.
  - Переменная `DOCKER_SYSTEM_PRUNE=true` перед сборкой очистит ненужные слои/объекты Docker.
  - Образ собирается с предустановленным [плагином запрета редактирования (Disable Editing Plugin)](https://gitlab.com/marmyshev/edt-editing). Плагин устанавливается из [update‑site плагина](https://marmyshev.gitlab.io/edt-editing/update) в процессе сборки.

Скрипт для локальной сборки — `build-edt.sh`.

[↑ Наверх](#onec-images)
