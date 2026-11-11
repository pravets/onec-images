# cs-base — базовый слой образов 1С:Сервера взаимодействия.
#
# Содержит JRE 11, полный продукт «1С:Сервер взаимодействия» (устанавливается
# штатным 1ce-installer-cli), утилиту ring, непривилегированного пользователя cs
# и общие скрипты подготовки и запуска компонентов.
#
# Дистрибутив скачивается отдельной стадией `downloader` тем же yard, что и
# платформа 1С / EDT, и монтируется в RUN, поэтому в слои образа не попадает.

ARG DOWNLOADER_REGISTRY_URL=sleemp
ARG DOWNLOADER_IMAGE=onec-installer-downloader
ARG DOWNLOADER_TAG=latest

FROM ${DOWNLOADER_REGISTRY_URL}/${DOWNLOADER_IMAGE}:${DOWNLOADER_TAG} AS downloader

# Версия сервера взаимодействия обязательна
ARG CS_VERSION
RUN : "${CS_VERSION:?CS_VERSION argument is required}"

# yard не привязан к конкретным продуктам: он читает общий список приложений
# releases.1c.ru/total и фильтрует их по названию приложения и заголовку ссылки
# на дистрибутив (см. https://releases.1c.ru/project/CollaborationSystem).
# --download-only обязателен: установщику CS нужен архив, а не распакованное дерево.
ARG CS_YARD_APP_FILTER="Сервер взаимодействия"
ARG CS_YARD_DISTR_FILTER="Сервер взаимодействия \(64-bit\) Linux"

RUN --mount=type=secret,id=onec_username \
    --mount=type=secret,id=onec_password \
    export YARD_RELEASES_USER=$(cat /run/secrets/onec_username) && \
    export YARD_RELEASES_PWD=$(cat /run/secrets/onec_password) && \
    yard releases get \
      --app-filter "${CS_YARD_APP_FILTER}" \
      --version-filter "$(printf '%s' "${CS_VERSION}" | sed 's/\./\\./g')" \
      --distr-filter "${CS_YARD_DISTR_FILTER}" \
      --path /tmp/downloads \
      --download-only \
      --download-limit 1 \
    && mkdir -p /cs-distrib \
    && tarball="$(find /tmp/downloads -maxdepth 4 -name '1c_cs_*_linux_x86_64.tar.gz' -print -quit)" \
    && test -n "${tarball}" \
    && mv "${tarball}" /cs-distrib/ \
    && test -f "/cs-distrib/1c_cs_${CS_VERSION}_linux_x86_64.tar.gz"

# Начало основной стадии сборки
FROM ubuntu:24.04

ARG CS_VERSION
RUN : "${CS_VERSION:?CS_VERSION argument is required}"

ARG BUILD_DATE
ARG CS_UID=999
ARG CS_GID=999

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="cs-base" \
      org.opencontainers.image.description="1C:Collaboration server ${CS_VERSION} base layer: JRE 11, ring, components" \
      org.opencontainers.image.version="${CS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

ENV CS_PRODUCTS_HOME=/opt/1C/1CE \
    CS_ROOT=/var/cs \
    CS_USER=cs \
    CS_INSTANCE_NAME=cs

# gawk обязателен: утилита ring в своих shell-обёртках использует awk-функцию
# gensub, которой нет в mawk (awk по умолчанию в Ubuntu).
# gosu нужен, чтобы отдать процесс компонента непривилегированному пользователю;
# tini — как PID 1 (лаунчер порождает дочерние процессы).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-11-jre-headless \
        ca-certificates \
        curl \
        jq \
        gawk \
        gosu \
        tini \
        tar \
        unzip \
        tzdata \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* \
    && test -x "${JAVA_HOME}/bin/java" \
    && gawk --version > /dev/null

COPY src/cs-common/install-cs.sh /usr/local/bin/install-cs.sh
# Архив монтируется из стадии downloader и не становится слоем образа.
RUN chmod +x /usr/local/bin/install-cs.sh
RUN --mount=type=bind,from=downloader,target=/stage \
    /usr/local/bin/install-cs.sh /stage/cs-distrib
RUN rm -f /usr/local/bin/install-cs.sh

COPY src/cs-common/lib-cs.sh /usr/local/lib/cs/lib-cs.sh
COPY src/cs-common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY src/cs-common/run-component.sh /usr/local/bin/run-component.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/run-component.sh

RUN groupadd -r cs --gid "${CS_GID}" \
    && useradd -r -g cs --uid "${CS_UID}" -m --home-dir=/home/cs --shell=/bin/bash cs \
    && mkdir -p /var/cs /var/records /usr/local/lib/cs/prepare.d \
    && chown -R cs:cs /var/cs /home/cs /var/records

VOLUME ["/var/cs"]

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
