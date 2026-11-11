# Стек 1С:Сервера взаимодействия (docker compose)

Готовый стек из образов семейства `cs-*`: сам сервер взаимодействия, Hazelcast,
Elasticsearch и, опционально, сайт внешних пользователей, web-chat и RustFS.
PostgreSQL, медиасервер Janus и TURN/STUN — всегда внешние.

Полное руководство 1С по установке — `https://its.1c.ru/db/cs30doc`
(для 30.0.42). Этот документ описывает только особенности контейнерной поставки.

## Состав стека

| Сервис | Образ | Профиль | Роль |
|--------|-------|---------|------|
| `server` | `cs-server` | всегда | Сервер взаимодействия |
| `hazelcast` | `cs-hazelcast` | всегда | Кластерная координация |
| `elasticsearch` | `cs-elasticsearch` | всегда | Полнотекстовый поиск |
| `init` | `cs-server` | всегда | Разовая регистрация БД, S3, Janus, TURN |
| `site` | `cs-site` | `site` | Сайт внешних пользователей |
| `web-chat` | `cs-web-chat` | `site` | Web-chat |
| `rustfs` | `rustfs/rustfs` | `s3` | S3-хранилище файлов |

Без профиля поднимаются три основных сервиса и `init`.

## Что нужно подготовить заранее

1. **PostgreSQL 15 (внешняя).**
   Для промышленной эксплуатации рекомендуется сборка с патчами 1С
   (`https://releases.1c.ru/project/AddCompPostgre`).

   ```sql
   CREATE USER db_user WITH PASSWORD 'db_user_pwd' CREATEDB;
   CREATE DATABASE cs_db OWNER db_user;
   \c cs_db
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   ```

2. **`vm.max_map_count` на Linux-хосте** (требование Elasticsearch 5.6):

   ```bash
   sudo sysctl -w vm.max_map_count=262144
   # постоянно:
   echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
   ```

   Через `sysctls:` в compose это задавать нельзя: часть демонов (в том числе
   Docker Desktop) запрещает менять `vm.*` из контейнера, и `compose up` упадёт.

3. **Обратный прокси и TLS.** Клиенты 1С подключаются по `ws://` или `wss://`.
   Для `wss://` либо терминируйте TLS на прокси, либо задайте keystore у CS
   (`CS_WS_WSS=true` и `CS_WS_KEYSTORE_PATH`/`CS_WS_KEYSTORE_PASSWORD`/`CS_WS_KEYSTORE_FORMAT`).

4. **Внешний Janus** (если нужна видеосвязь) и **coturn** (если клиенты за NAT).

## Быстрый старт

```bash
cp .env.example .env
# отредактируйте .env: CS_DB_URL, CS_DB_USER, CS_DB_PASSWORD, CS_ADMIN_PASSWORD,
# CS_PUBLIC_URL, CS_PUBLIC_WS_URL

docker compose up -d
docker compose logs -f server
```

Проверка готовности:

```bash
curl -u admin:"$CS_ADMIN_PASSWORD" http://localhost:8087/rs/health
```

Ожидаемо после работы сервиса `init`:

```json
{"status":"UP","mainDbOk":true,"allShardsOk":true,
 "hazelcast":{"available":true,"members":["..."]},
 "elasticsearchOk":true,"mediaClusterOk":false,"pushOk":false}
```

`mediaClusterOk:false` — нормально, если видеосвязь не подключена.

### Первый запуск: что происходит

1. `hazelcast` и `elasticsearch` создают экземпляры в томе `/var/cs` и стартуют.
2. `server` создаёт экземпляр CS, пишет конфигурацию из переменных окружения
   (WebSocket, админ-REST, JDBC-пулы, адреса Hazelcast/Elasticsearch, лог в консоль)
   и запускает компонент от пользователя `cs`.
3. `init` ждёт `/rs/health` (по имени сервиса `server`, т.к. это отдельный
   контейнер), регистрирует основную БД, S3, Janus и TURN
   и ставит маркер `/var/cs/cs_instance/.bootstrap-done`.

Регистрация **идемпотентна**: перед созданием сущности проверяется её наличие
по URL/имени бакета. Поведение задаётся `CS_BOOTSTRAP`:

- `once` (по умолчанию) — только если маркера нет;
- `always` — при каждом запуске;
- `never` — не регистрировать (всё настроено вручную).

Ошибка регистрации по умолчанию не роняет контейнер (`CS_BOOTSTRAP_STRICT=false`),
но и маркер не выставляется — при следующем запуске регистрация повторится.

## Сценарии

### 1. Всё встроенное (dev/тест)

`compose up -d` + профили `site` и `s3`. Единственная внешняя зависимость — PostgreSQL.

```bash
docker compose --profile site --profile s3 up -d
```

В `.env` для встроенного RustFS:

```ini
CS_S3_ENDPOINT=http://rustfs:9000
CS_S3_BUCKET=cs-bucket
CS_S3_ACCESS_KEY=rustfs
CS_S3_SECRET_KEY=<секрет>
CS_S3_SIGNATURE_VERSION=V4
```

Бакет `cs-bucket` создаётся один раз: консоль RustFS `http://<хост>:9001`
(логин/пароль — `CS_S3_ACCESS_KEY`/`CS_S3_SECRET_KEY`) или любой S3-клиент.
Это ровно тот шаг, который руководство 1С описывает для MinIO (раздел 9.2).
Пример через AWS CLI:

```bash
docker run --rm --network cs_cs \
  -e AWS_ACCESS_KEY_ID=rustfs -e AWS_SECRET_ACCESS_KEY=<секрет> \
  -e AWS_DEFAULT_REGION=eu-west-1 -e AWS_EC2_METADATA_DISABLED=true \
  amazon/aws-cli:latest \
  s3api create-bucket --bucket cs-bucket --endpoint-url http://rustfs:9000
```

RustFS работает по AWS Signature **V4** — именно поэтому
`CS_S3_SIGNATURE_VERSION=V4`. Контейнер RustFS работает от uid `10001`;
каталог логов по умолчанию `/logs` (внутри образа), не переопределяйте его на
`/var/log/...` — только на записываемый том (например `RUSTFS_LOG_DIRECTORY=/data/logs`).

### 2. Гибрид (рекомендуется для промышленной эксплуатации)

Встроенные CS, Hazelcast, Elasticsearch; внешние PostgreSQL, S3 и Janus:

```ini
CS_DB_URL=jdbc:postgresql://pg.prod:5432/cs_db?currentSchema=public
CS_S3_ENDPOINT=https://s3.prod
CS_MEDIA_SERVER_URL=http://janus.prod:8188/janus/
CS_TURN_URL=turn:turn.prod:3478
```

### 3. Всё внешнее

Поднимается только `server`; Hazelcast и Elasticsearch указываются адресами:

```ini
CS_HAZELCAST_ADDRESSES=hc1.prod,hc2.prod
CS_HAZELCAST_GROUP_NAME=1ce-cs
CS_HAZELCAST_GROUP_PASSWORD=<пароль>
CS_ES_ADDRESSES=es1.prod:9300,es2.prod:9300
CS_ES_CLUSTER_NAME=1ce-cs
```

Для внешнего кластера Hazelcast участников задают в самом кластере; для CS
достаточно списка адресов. Имя группы и пароль **должны совпадать** у CS и
Hazelcast, иначе клиент CS не попадёт в кластер.

## Подключение информационной базы 1С

После того как стек поднялся:

1. В клиенте 1С: **Файл → Открыть → `CollaborationSystemRegister.epf`**
   (обработка входит в дистрибутив сервера взаимодействия).
2. Адрес сервера взаимодействия: `ws://<хост>:8086` (или `wss://<хост>` за прокси).
3. Нажать «Зарегистрировать».

## Видеосвязь (внешний Janus)

1. Поднимите Janus 1С-сборки на отдельном хосте (в этот репозиторий его образ
   не входит: дистрибутив `janus-amd64-*.tar.gz` поставляется отдельно).
2. В `.env`:

   ```ini
   CS_VIDEO_ENABLED=true
   CS_MEDIA_SERVER_URL=http://janus.example.com:8188/janus/
   CS_MEDIA_SERVER_NAME=Janus 1
   CS_MEDIA_CONFEREE_LIMIT=1000
   CS_TURN_URL=turn:turn.example.com:3478
   CS_TURN_USER=video_module
   CS_TURN_PASSWORD=<пароль>
   ```

3. Перезапустите `server` и `init`:

   ```bash
   docker compose up -d server init
   ```

4. Проверьте `mediaClusterOk: true` в `/rs/health`.

Порты Janus: `8188` (HTTP API) и `7188` (внутренний API). Порты TURN/STUN — `3478`.

## Логи и диагностика

```bash
docker compose logs -f server          # консольный лог CS (CS_LOG_CONSOLE=true)
docker compose exec server ls /var/cs/cs_instance/logs
docker compose exec server tail -100 /var/cs/cs_instance/logs/server.log
docker compose exec hazelcast ls /var/cs/hazelcast_instance
docker compose exec elasticsearch curl -s http://127.0.0.1:9200/
```

Уровень логов CS: `CS_LOG_LEVEL=TRACE|DEBUG|INFO|WARN|ERROR` (по умолчанию `WARN`).
Отключить вывод в консоль (только файлы): `CS_LOG_CONSOLE=false`.

## Обновление версии CS

Порядок из официального руководства по обновлению (для минорных обновлений):

1. Собрать образы новой версии (`CS_VERSION=<новая>`).
2. Остановить сервисы: `docker compose stop server hazelcast elasticsearch`.
3. Обновить образы: `docker compose pull` (или пересобрать локально).
4. Поднять: `docker compose up -d`.

При обновлении **мажорной** версии руководство 1С требует удалить и заново
создать экземпляры (`ring … instance delete`, затем `instance create`).
Конфигурация в этом случае генерируется заново из `.env` при следующем старте —
достаточно удалить каталоги экземпляров в томе `server-data`/`hazelcast-data`/`elasticsearch-data`.
Перед этим обязательно сделайте резервную копию PostgreSQL.

После обновления при необходимости пересоберите индексы поиска:

```bash
curl -u admin:"$CS_ADMIN_PASSWORD" -L -X POST \
  "http://localhost:8087/admin/search_objects/recreate_index?load=true"
curl -u admin:"$CS_ADMIN_PASSWORD" -L -X POST \
  "http://localhost:8087/admin/search_users/recreate_index?load=true"
```

## Типовые проблемы

| Симптом | Причина и решение |
|---------|-------------------|
| `mainDbOk:false` | CS не видит PostgreSQL: проверьте `CS_DB_URL` (из контейнера `localhost` — это сам контейнер), доступность порта 5432 и что расширение `uuid-ossp` создано |
| `elasticsearchOk:false` | Адрес должен содержать **транспортный** порт 9300 (`es:9300`), имя кластера — совпадать с `CS_ES_CLUSTER_NAME` |
| `hazelcast.available:false` | Не совпадают имя группы/пароль у CS и Hazelcast, либо недоступен порт 5701 |
| Elasticsearch падает с `max virtual memory areas too low` | На хосте не задан `vm.max_map_count=262144` (см. выше) |
| `init` завершился ошибкой | Смотрите `docker compose logs init`; при необходимости `CS_BOOTSTRAP_STRICT=true`, чтобы ошибка была явной |
| Клиенты не подключаются | Проверьте внешний адрес и порт 8086, а для `wss://` — TLS на прокси |
| RustFS падает с `mkdir: cannot create directory '/var/log/rustfs'` | Не переопределяйте `RUSTFS_LOG_DIRECTORY` на путь вне тома данных: контейнер работает от uid 10001. Оставьте `/logs` или задайте `/data/logs` |
| S3-регистрация не проходит | Проверьте, что бакет создан, а `CS_S3_ENDPOINT` не указывает на `localhost`; версия подписи должна соответствовать хранилищу (`V4` для RustFS) |
| Пустые логи в `docker compose logs server` | `CS_LOG_CONSOLE=false`; логи лежат в `/var/cs/cs_instance/logs/server.log` |

## Безопасность

- Смените `CS_ADMIN_PASSWORD` (по умолчанию в образах `admin`/`admin`).
- Смените `CS_HAZELCAST_GROUP_PASSWORD` и пароли S3 и TURN.
- Не публикуйте порты 8087 (админ-REST), 9000/9001 (RustFS) и 9200 наружу —
  в `compose.yaml` они доступны только внутри сети стека, наружу опубликован
  лишь RustFS в профиле `s3`.
- Терминируйте TLS на обратном прокси; наружу отдавайте только 8086/8443
  (или прокси-порты).
