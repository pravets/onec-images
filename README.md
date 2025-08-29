# onec-images

![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/pravets/onec-images?utm_source=oss&utm_medium=github&utm_campaign=pravets%2Fonec-images&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)
![License](https://img.shields.io/github/license/pravets/oscript-images)
[![Telegram](https://telegram-badge.vercel.app/api/telegram-badge?channelId=@pravets_IT)](https://t.me/pravets_it)

Всё необходимое для сборки docker-образов с платформой 1С и сопутствующими инструментами.

## Оглавление

- [Как собрать образы](#как-собрать-образы)
    - [Сборка через GitHub Actions](#сборка-через-github-actions)
    - [Локальная сборка](#локальная-сборка)
- [1С:Исполнитель (executor)](#1сисполнитель)
- [1С:EDT (edt)](#1сedt)
- [1С:EDT CLI (edtcli)](#1сedt-cli)
- [1С:Платформа (onec-platform)](#1сплатформа-onec-platform)
- [vanessa-runner (vrunner)](#vanessa-runner-vrunner)

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
  - Базовый образ `edt` собирается БЕЗ `ENTRYPOINT` для корректной работы в GitLab CI. Запуск `1cedtcli` выполняется явно (в производных образах, таких как `edtcli`, задаётся `ENTRYPOINT`).

Скрипт для локальной сборки — `build-edt.sh`.

[↑ Наверх](#onec-images)

## 1С:EDT CLI

Образ-обёртка над базовым `edt`, который добавляет `ENTRYPOINT` с `1cedtcli` и объявляет том `/edt`. Собирается одновременно с базовым образом EDT.

- Требования:
  - `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD` — доступ к приватному реестру, содержащему базовый образ `edt`.
  - `EDT_VERSION` — версия EDT, совпадает с базовым образом.

- Локальная сборка:
  1. Убедитесь, что в реестре доступен образ `edt:$EDT_VERSION`. Если образ отсутствует локально — скрипт авторизуется и попытается сделать `docker pull`. Если образа нет и в реестре — скрипт выполнит локальную сборку базового `edt` через `build-edt.sh`, а затем соберёт `edtcli`. При этом, если был собран образ `edt`, то он будет запушен, если пуш явно не запрещён при сборке `edtcli` через `PUSH_IMAGE=false`
  2. Запуск: `./src/build-edtcli.sh`

- Результат локальной сборки — образ с тегом `$DOCKER_REGISTRY_URL/edtcli:$EDT_VERSION`.

[↑ Наверх](#onec-images)

## 1С:Платформа (onec-platform)

Для сборки требуется доступ к сайту релизов 1С для скачивания установщиков платформы. Данные учётной записи необходимо передать через переменные среды/секреты `ONEC_USERNAME` и `ONEC_PASSWORD`.

- Сборка в GitHub Actions (PR‑проверки):
  - Есть workflow `ci-onec-platform.yml`, который при изменении файлов в `src/onec-platform/*.Dockerfile` автоматически формирует матрицу версий и собирает соответствующие образы без публикации в реестр.
  - Секреты: `ONEC_USERNAME`, `ONEC_PASSWORD`.
  
- Сборка и публикация через GitHub Actions по тегу:
  - Триггером является тег вида `onec_platform_ВерсияПлатформы`, например `onec_platform_8.3.22.2557`.
  - После выпуска такого тега workflow соберёт и опубликует образ `onec-platform:$ONEC_VERSION` в указанный реестр.

- Локальная сборка:
  1. Заполните `.env` значениями `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD`, `ONEC_USERNAME`, `ONEC_PASSWORD`.
  2. Укажите версию платформы 1С (поддерживаются минорные ветки 8.3.20–8.3.27). Скрипт выбирает `Dockerfile` по первым трём компонентам версии: `8.3.22.x` → `src/onec-platform/8.3.22.Dockerfile`.
     - однократно в текущей сессии: `export ONEC_VERSION=8.3.22.2557`
     - либо инлайном при запуске: `ONEC_VERSION=8.3.22.2557 ./src/build-onec-platform.sh`
  3. Запустите сборку: `./src/build-onec-platform.sh`.

- Результат локальной сборки — образ с тегом `$DOCKER_REGISTRY_URL/onec-platform:$ONEC_VERSION`.

- Полезно знать:
  - `PUSH_IMAGE=false` — собрать без публикации в реестр.
  - `NO_CACHE=true` — отключить кэш сборки.
  - `DOCKER_SYSTEM_PRUNE=true` — предварительно очистить неиспользуемые слои/объекты Docker.
  - Секреты для скачивания установщиков передаются в сборку через BuildKit‑секреты, которые готовятся скриптом `scripts/prepare_onec_credentials.sh` на основе переменных `ONEC_USERNAME`/`ONEC_PASSWORD`.

[↑ Наверх](#onec-images)

## vanessa-runner (vrunner)

`vrunner` — образ-обёртка для vanessa-runner. Он создаётся на базе `onec-platform` (onec-docker).

- При сборке `vrunner` скрипт `src/build-vrunner.sh` сначала проверяет наличие базового образа локально (без префикса и с префиксом). Если образ не найден локально, скрипт попытается выполнить `docker pull` из реестра — но только если задан реальный `DOCKER_REGISTRY_URL` (в CI для fork'ов по умолчанию может использоваться безопасный префикс `local`, при котором pull не выполняется).
- Если базовый образ отсутствует и в реестре, `build-vrunner.sh` автоматически вызовет `./src/build-onec-platform.sh` для локальной сборки базового образа `onec-platform:$ONEC_VERSION`. При включённом `PUSH_IMAGE=true` базовый образ будет также запушен в реестр.

Требования и ключевые переменные:
- `ONEC_VERSION` — версия платформы (например `8.3.27.1644`). Для tag-trigger сборок переменная вычисляется из имени тега `vrunner_<ONEC_VERSION>`.
- `DOCKER_REGISTRY_URL`, `DOCKER_LOGIN`, `DOCKER_PASSWORD` — для доступа к приватному реестру.
- `ONEC_USERNAME`, `ONEC_PASSWORD` — для скачивания установщиков платформы в процессе сборки `onec-platform`.
- `PUSH_IMAGE` — если `false`, сборка не будет пушить итоговый образ (удобно для локальной проверки и PR).

Примеры:

Локальная сборка (с автоматическим созданием базового образа, если его нет):

```bash
# собрать vrunner (если нет onec-platform — будет собран локально)
PUSH_IMAGE=false ONEC_VERSION=8.3.27.1644 ./src/build-vrunner.sh
```

Сборка через GitHub Actions по тегу (пример):

1. Создайте тег `vrunner_8.3.27.1644` и запушьте его в репозиторий.
2. Workflow извлечёт `ONEC_VERSION` из тега и запустит `./src/build-vrunner.sh`. При необходимости будет предварительно собран и (если разрешён) запущен push базового `onec-platform`.

[↑ Наверх](#onec-images)
