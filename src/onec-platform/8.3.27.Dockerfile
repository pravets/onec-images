# Используем стандартный образ скачивателя как в EDT
ARG DOWNLOADER_REGISTRY_URL=sleemp
ARG DOWNLOADER_IMAGE=onec-installer-downloader
ARG DOWNLOADER_TAG=latest

FROM ${DOWNLOADER_REGISTRY_URL}/${DOWNLOADER_IMAGE}:${DOWNLOADER_TAG} AS downloader

# Версия платформы 1С обязательна
ARG ONEC_VERSION
RUN : "${ONEC_VERSION:?ONEC_VERSION argument is required}"

WORKDIR /tmp

# Загружаем дистрибутивы через downloader с секретами BuildKit
# Ожидаемый путь выгрузки: /tmp/downloads/Platform83/${ONEC_VERSION}
RUN --mount=type=secret,id=onec_username \
    --mount=type=secret,id=onec_password \
    export YARD_RELEASES_USER=$(cat /run/secrets/onec_username) && \
    export YARD_RELEASES_PWD=$(cat /run/secrets/onec_password) && \
    /app/downloader.sh server "$ONEC_VERSION"

# Начало основной стадии сборки
FROM ubuntu:24.04 AS base

# Копируем скрипты и файлы установки
ARG ONEC_VERSION
ARG nls_enabled=false
ENV nls=$nls_enabled
ENV distrPath=/tmp/downloads/Platform83/${ONEC_VERSION}
ENV installer_type=server

COPY ./scripts/onec-install.sh /onec-install.sh
# Копируем только скачанные дистрибутивы нужной версии
COPY --from=downloader /tmp/downloads/Platform83/${ONEC_VERSION} /tmp/downloads/Platform83/${ONEC_VERSION}
WORKDIR ${distrPath}      

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN ls . \
  && chmod +x /onec-install.sh \
  && sync; /onec-install.sh

# create symlink to current 1c:enterprise directory
COPY ./scripts/create-symlink-to-current-1cv8.sh /create-symlink-to-current-1cv8.sh
RUN chmod +x /create-symlink-to-current-1cv8.sh \
  && /create-symlink-to-current-1cv8.sh \
  && rm /create-symlink-to-current-1cv8.sh

FROM ubuntu:24.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ONEC_VERSION
ARG BUILD_DATE
LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="onec-platform" \
      org.opencontainers.image.description="1C:Enterprise platform runtime ${ONEC_VERSION}" \
      org.opencontainers.image.version="${ONEC_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ARG onec_uid="999"
ARG onec_gid="999"

COPY --from=base /opt /opt

RUN set -xe \
  && apt-get update \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      locales \
      ca-certificates \
      libwebkit2gtk-4.1-0 \
      ttf-mscorefonts-installer \
      libfontconfig1 \
      libgsf-1-114 \
      libglib2.0-0 \
      libodbc2 \
      libmagickwand-6.q16-7t64 \
      libsm6 \
      libglu1-mesa \
      dbus-x11 \
      xvfb \
      xkb-data \
  && rm -rf  \
    /var/lib/apt/lists/* \
    /var/cache/debconf \
    /var/cache/apt/* \
    /tmp/* \
  && locale-gen ru_RU.UTF-8 \
  && update-locale LANG=ru_RU.UTF-8 \
  && install -d -m 1777 -o root -g root /tmp/.X11-unix

ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV XKB_CONFIG_ROOT=/usr/share/X11/xkb
ENV NO_AT_BRIDGE=1

RUN groupadd -r grp1cv8 --gid=$onec_gid \
  && useradd -r -g grp1cv8 --uid=$onec_uid -m --home-dir=/home/usr1cv8 --shell=/bin/bash usr1cv8 \
  && mkdir -p /home/usr1cv8/.1cv8 \
  && chown -R usr1cv8:grp1cv8 /home/usr1cv8 \
  && chown -R usr1cv8:grp1cv8 /opt/1cv8/current

VOLUME /home/usr1cv8/.1cv8

ENV PATH="/opt/1cv8/current:$PATH"

COPY --chown=usr1cv8:grp1cv8 ./configs/onec/conf/ /opt/1cv8/current/

WORKDIR /home/usr1cv8

USER usr1cv8

CMD ["bash"]