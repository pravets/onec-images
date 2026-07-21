# AGENTS.md

Файл для AI-агентов, работающих с проектом `onec-images`. Здесь собраны сведения об архитектуре, сборке, тестировании и принятых соглашениях.

## Обзор проекта

`onec-images` — репозиторий для сборки Docker-образов вокруг экосистемы **1С:Предприятие** и связанных инструментов.

Проект вдохновлён [onec-docker](https://github.com/firstBitMarksistskaya/onec-docker), но фокусируется на минимальном наборе образов, автоматизированной сборке через GitHub Actions и тестировании образов.

Основные цели:

- Поставка Docker-образов для платформы 1С, 1С:EDT, 1С:Исполнителя, vanessa-runner и MCP-серверов поверх EDT.
- Автоматическая сборка и публикация по git-тегам.
- Минимальное, но обязательное тестирование каждого собранного образа перед пушем.

## Технологический стек

- **Docker + BuildKit** — многоэтапные сборки, передача секретов через `--mount=type=secret`.
- **Bash** — язык всех скриптов сборки, тестов и утилит.
- **Ubuntu** — базовый образ для платформы 1С, EDT (2025–2026), Исполнителя.
- **eclipse-temurin:17** — базовый образ для EDT 2023–2024.
- **Mono + OneScript (oscript)** — для образов `vrunner` / `vrunner2`.
- **GitHub Actions** — CI/CD: сборка по тегам и PR-проверки.
- **Внешний downloader** — `sleemp/onec-installer-downloader:latest` используется для скачивания дистрибутивов 1С и EDT с сайта релизов.

## Структура репозитория

```text
onec-images/
├── .github/workflows/     # GitHub Actions: сборка по тегам и PR-проверки
├── configs/onec/conf/     # Конфигурация платформы 1С (conf.cfg), копируется в образ
├── scripts/               # Вспомогательные bash-скрипты
├── src/                   # Dockerfile и скрипты сборки образов
│   ├── build-*.sh         # Точки входа для сборки каждого образа
│   ├── edt/               # Dockerfile базовых образов EDT (2023, 2024, 2025, 2026)
│   ├── edtcli/            # Образ-обёртка с ENTRYPOINT=1cedtcli
│   ├── edt-mcp-server/    # EDT + MCP-сервер (EDT-MCP)
│   ├── edt-codepilot1c/   # EDT + CodePilot1C MCP Server
│   ├── executor/          # 1С:Исполнитель
│   ├── onec-platform/     # 1С:Платформа (8.3.20–8.3.27)
│   ├── vrunner/           # vanessa-runner 3.x (SNAPSHOT)
│   └── vrunner2/          # vanessa-runner 2.6.1
├── tests/                 # Тесты для каждого образа
├── tools/assert.sh        # Библиотека ассертов на bash
├── .env.example           # Пример переменных окружения
└── README.md              # Пользовательская документация (русский язык)
```

## Образы и их назначение

### `onec-platform`

- Серверная платформа 1С:Предприятие.
- Поддерживаются минорные ветки **8.3.20–8.3.27**.
- Dockerfile выбирается по первым трём компонентам версии: `8.3.22.x` → `src/onec-platform/8.3.22.Dockerfile`.
- Ubuntu 20.04 для 8.3.20–8.3.21, Ubuntu 24.04 для 8.3.22–8.3.27.
- В образе пользователь `usr1cv8:grp1cv8` (uid/gid 999), `/opt/1cv8/current` добавлен в `PATH`.

### `edt`

- Базовый образ 1С:EDT без `ENTRYPOINT` (для совместимости с GitLab CI).
- Поддерживаются версии **2023, 2024, 2025, 2026**.
- В образе устанавливается плагин запрета редактирования (`edt-editing`) из update-site.
- В образах EDT 2025.1 и новее плагин **1C:Workmate** (`com.e1c.edt.ai.feature.feature.group`) удаляется на этапе сборки.
- `EDT_JAVA_XMX=12g` по умолчанию.

### `edtcli`

- Образ-наследник `edt` с `ENTRYPOINT ["1cedtcli"]` и томом `/edt`.
- Собирается вместе с базовым `edt` в CI.

### `edt-mcp-server`

- EDT + плагин [EDT-MCP](https://github.com/DitriXNew/EDT-MCP).
- Запускает EDT через `Xvfb`, предоставляет MCP-сервер на порту `8765`.
- Поддерживается EDT `>= 2025.2.3`.

### `edt-codepilot1c`

- EDT + плагин [CodePilot1C](https://github.com/ondysss/codepilot1c-edt).
- Headless-режим EDT, HTTP MCP-сервер на порту `8765`.
- Bearer-токен генерируется автоматически при первом запуске или берётся из `EDT_CODEPILOT_BEARERTOKEN`.

### `executor`

- Образ 1С:Исполнителя.
- Скачивается с `https://developer.1c.ru` по API-ключу `DEV1C_EXECUTOR_API_KEY`.

### `vrunner` / `vrunner2`

- vanessa-runner поверх `onec-platform`.
- `vrunner` — vanessa-runner 3.x из канала `SNAPSHOT`.
- `vrunner2` — vanessa-runner 2.6.1.
- Требуют Mono, OneScript (OVM) и базовый образ `onec-platform`.

## Переменные окружения

Создайте `.env` на основе `.env.example`:

```bash
cp .env.example .env
```

Общие переменные:

| Переменная | Назначение |
|------------|------------|
| `DOCKER_REGISTRY_URL` | URL Docker-реестра (`library` или локальный префикс для тестов) |
| `DOCKER_LOGIN` | Логин в реестр |
| `DOCKER_PASSWORD` | Пароль в реестр |
| `PUSH_IMAGE` | `true`/`false` — публиковать ли образ после сборки |
| `NO_CACHE` | `true` — отключить кэш Docker |
| `DOCKER_SYSTEM_PRUNE` | `true` — очистить `docker system prune -af` перед сборкой |

Переменные для 1С:

| Переменная | Назначение |
|------------|------------|
| `ONEC_USERNAME` | Логин к сайту релизов 1С |
| `ONEC_PASSWORD` | Пароль к сайту релизов 1С |
| `ONEC_VERSION` | Версия платформы, например `8.3.27.1644` |

Переменные для EDT:

| Переменная | Назначение |
|------------|------------|
| `EDT_VERSION` | Версия EDT, например `2025.2.3` |
| `EDT_MCP_VERSION` | Версия плагина EDT-MCP |
| `EDT_CODEPILOT_VERSION` | Версия плагина CodePilot1C |
| `EDT_JAVA_XMX` | Размер кучи JVM (по умолчанию `12g`) |

Переменные для Исполнителя:

| Переменная | Назначение |
|------------|------------|
| `EXECUTOR_VERSION` | Версия 1С:Исполнителя |
| `DEV1C_EXECUTOR_API_KEY` | API-ключ с `developer.1c.ru` |

## Как собирать образы локально

Сборка возможна только на Linux.

```bash
# Платформа 1С
ONEC_VERSION=8.3.27.1644 ./src/build-onec-platform.sh

# EDT
EDT_VERSION=2025.2.3 ./src/build-edt.sh

# EDT CLI (требует локально собранный или запуленный образ edt)
EDT_VERSION=2025.2.3 ./src/build-edtcli.sh

# EDT MCP Server
EDT_VERSION=2025.2.3 EDT_MCP_VERSION=1.24.5 ./src/build-edt-mcp-server.sh

# EDT CodePilot1C
EDT_VERSION=2025.2.3 EDT_CODEPILOT_VERSION=0.1.7.20260301-0607 ./src/build-edt-codepilot1c.sh

# Исполнитель
EXECUTOR_VERSION=3.0.2.2 ./src/build-executor.sh

# vanessa-runner
ONEC_VERSION=8.3.27.1644 ./src/build-vrunner.sh
ONEC_VERSION=8.3.27.1644 ./src/build-vrunner2.sh
```

Для локальной проверки без публикации:

```bash
PUSH_IMAGE=false ONEC_VERSION=8.3.27.1644 ./src/build-vrunner.sh
```

Скрипты автоматически:

- Загружают `.env` через `scripts/load_env.sh`, если не запущены в CI (`CI` не задан).
- Подготавливают учётные данные / API-ключ через `scripts/prepare_*`.
- Логинятся в реестр, если `PUSH_IMAGE=true`.
- Запускают тесты из `tests/test-*.sh`.
- Пушат образ только если тесты прошли.
- Выполняют `scripts/cleanup.sh`.

## Скрипты в `scripts/`

| Скрипт | Назначение |
|--------|------------|
| `load_env.sh` | Загружает переменные из `.env` |
| `docker_login.sh` | Авторизуется в Docker-реестре |
| `prepare_onec_credentials.sh` | Записывает `ONEC_USERNAME`/`ONEC_PASSWORD` в `/tmp/onec_username` и `/tmp/onec_password` для BuildKit-секретов |
| `prepare_executor_api_key.sh` | Записывает `DEV1C_EXECUTOR_API_KEY` в `/tmp/dev1c_executor_api_key.txt` |
| `onec-install.sh` | Устанавливает платформу 1С из `.deb` или `.run` дистрибутива |
| `create-symlink-to-current-1cv8.sh` | Создаёт `/opt/1cv8/current` → директория платформы |
| `ensure_edtcli_symlink.sh` | Обеспечивает единообразие имён `1cedtcli` ↔ `1cedtcli.sh` |
| `cleanup.sh` | Удаляет временные секреты и разлогинивается из Docker |

## Тестирование

- Каждый образ имеет парный тест в `tests/test-<image>.sh`.
- Тесты запускаются автоматически из build-скриптов.
- Если тесты не проходят, образ **не публикуется**.
- Используется библиотека `tools/assert.sh` (`assert_eq`, `assert_contain`, `log_success`, `log_failure` и др.).
- В CI тесты обязательно влияют на exit code; локально (`CI` не задан) тесты выводят результат, но скрипт завершается с `0`.

Примеры тестов:

- `test-onec-platform.sh` — создаёт файловую информационную базу через `1cv8 CREATEINFOBASE`.
- `test-edt.sh` — проверяет, что `1cedtcli` / `1cedtcli.sh` запускаются и версия совпадает.
- `test-edt-mcp-server.sh` / `test-edt-codepilot1c.sh` — проверяют установку плагина, настройки `1cedt.ini` и доступность `/health`.
- `test-executor.sh` — проверяет вывод `--version`.
- `test-vrunner.sh` / `test-vrunner2.sh` — проверяют help и создание базы через `init-dev --ibcmd`.

## CI/CD (GitHub Actions)

### Сборка и публикация по тегам

| Тег | Workflow | Собираемые образы |
|-----|----------|-------------------|
| `onec_platform_<VERSION>` | `build-onec-platform.yml` | `onec-platform` |
| `edt_<VERSION>` | `build-edt.yml` | `edt` + `edtcli` |
| `edt-mcp-server_<EDT>_<MCP>` | `build-edt-mcp-server.yml` | `edt-mcp-server` |
| `edt-codepilot1c_<EDT>_<CodePilot>` | `build-edt-codepilot1c.yml` | `edt-codepilot1c` |
| `executor_<VERSION>` | `build-executor.yml` | `executor` |
| `vrunner_<VERSION>` | `build-vrunner.yml` | `vrunner` |
| `vrunner2_<VERSION>` | `build-vrunner2.yml` | `vrunner2` |

### PR-проверки (build-only, без пуша)

| Workflow | Триггер | Примечание |
|----------|---------|------------|
| `ci-onec-platform.yml` | изменения в платформе / vrunner / скриптах | Матрица версий 8.3.20–8.3.27 |
| `ci-edt.yml` | изменения в EDT / edtcli | Матрица 2023.3.6, 2024.2.6, 2025.1.5, 2025.2.3, 2026.1.2 |
| `ci-executor.yml` | изменения в executor | Матрица версий Исполнителя |
| `ci-edt-mcp-server.yml` | изменения в edt-mcp-server | EDT 2025.2.3 + MCP 1.24.5 |
| `ci-edt-codepilot1c.yml` | изменения в edt-codepilot1c | EDT 2025.2.3 + CodePilot 0.1.7.20260301-0607 |

В PR-workflow используется `DOCKER_REGISTRY_URL=local` и `PUSH_IMAGE=false`.

## Соглашения по коду

- Все скрипты начинаются с `#!/bin/bash` или `#!/usr/bin/env bash` и включают `set -euo pipefail` / `set -eo pipefail`.
- Build-скрипты используют `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` для относительных путей.
- В CI переменные берутся из `secrets`; локально — из `.env`.
- Секреты не передаются через `ARG`/`ENV` в Dockerfile, только через BuildKit `--mount=type=secret`.
- Временные файлы с секретами создаются в `/tmp` и удаляются в `cleanup.sh`.
- Тесты определяют `CI`-окружение и ведут себя соответственно.

## Соглашения по коммитам

- Каждый изменённый файл коммитится отдельно (не используй `git add -A` для группового коммита нескольких файлов).
- Сообщения коммитов оформляются по [Conventional Commits](https://www.conventionalcommits.org/):
  - `feat:` — новая функциональность;
  - `fix:` — исправление ошибки;
  - `chore:` — рутинные изменения (обновление версий плагинов, мелкие правки);
  - `ci:` — изменения CI/CD;
  - `docs:` — изменения документации;
  - `refactor:` — рефакторинг без изменения поведения;
  - `test:` — изменения тестов.
- Описание коммита пишется на русском языке в совершённом виде (например, «добавлен», «исправлен», «обновлён»).
- Формат сообщения: `<type>: <краткое описание изменения>`.
- Примеры:
  - `feat: добавлен Dockerfile для EDT 2026`
  - `ci: обновлена версия EDT в матрице сборки`
  - `docs: обновлена документация для поддержки EDT 2026`

## Безопасность

- Не коммитьте `.env` и файлы с API-ключами (они указаны в `.gitignore`).
- `ONEC_USERNAME`, `ONEC_PASSWORD`, `DEV1C_EXECUTOR_API_KEY`, `DOCKER_PASSWORD` — хранятся только в GitHub Secrets.
- BuildKit-секреты (`--mount=type=secret`) не попадают в слои образа.
- `cleanup.sh` выполняет `docker logout` и удаляет временные файлы.
- Образы `onec-platform` запускаются от непривилегированного пользователя `usr1cv8`.

## Полезные приёмы

- Принудительная пересборка базового `edt` для производных образов:
  ```bash
  FORCE_BUILD_BASE=true EDT_VERSION=2025.2.3 EDT_MCP_VERSION=1.24.5 ./src/build-edt-mcp-server.sh
  ```
- Отключение кэша:
  ```bash
  NO_CACHE=true ./src/build-onec-platform.sh
  ```
- Очистка Docker перед сборкой:
  ```bash
  DOCKER_SYSTEM_PRUNE=true ./src/build-edt.sh
  ```

## Лицензия

MIT License. Автор: Iosif Pravets.
