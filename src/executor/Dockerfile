# Используем официальный базовый образ
ARG DOCKER_REGISTRY_URL=library
ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=22.04
FROM ${DOCKER_REGISTRY_URL}/${BASE_IMAGE}:${BASE_TAG}

LABEL maintainer="i@pravets.ru"
LABEL author="Iosif Pravets"

ARG EXECUTOR_VERSION

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    locales \
    ca-certificates \
    # downloader dependencies
    curl \
    # build dependencies
    unzip \
  && rm -rf  \
    /var/lib/apt/lists/* \
    /var/cache/debconf \
    /tmp/* \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8

ENV LANG=ru_RU.UTF-8

# Install Executor (используем BuildKit secret)
RUN --mount=type=secret,id=dev1c_executor_api_key \
  curl -sSL --fail \
    -H "X-Developer-1c-Api:$(cat /run/secrets/dev1c_executor_api_key)" \
    -o executor.zip \
    https://developer.1c.ru/applications/Console/api/v1/download/executor/${EXECUTOR_VERSION}/linux \
  && unzip executor.zip \
  && rm executor.zip \
  && mkdir /opt/executor \
  && cp -R * /opt/executor \
# cleanup
  && rm -rf /tmp/* \
  && apt purge -y unzip

ENV PATH="/opt/executor:$PATH"
ENTRYPOINT ["/opt/executor/executor"]
