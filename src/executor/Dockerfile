# Используем многоэтапную сборку: builder для скачивания/распаковки, runtime — минимальный рантайм
ARG DOCKER_REGISTRY_URL=library
ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=24.04

FROM ${DOCKER_REGISTRY_URL}/${BASE_IMAGE}:${BASE_TAG} AS builder

ARG EXECUTOR_VERSION

WORKDIR /tmp

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    unzip \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

# Install Executor (используем BuildKit secret)
RUN --mount=type=secret,id=dev1c_executor_api_key \
  curl -sSL --fail \
    -H "X-Developer-1c-Api:$(cat /run/secrets/dev1c_executor_api_key)" \
    -o executor.zip \
    https://developer.1c.ru/applications/Console/api/v1/download/executor/${EXECUTOR_VERSION}/linux \
  && mkdir -p /opt/1C/executor \
  && unzip -q -d /opt/1C/executor executor.zip \
  && rm -f executor.zip \
  && test -x /opt/1C/executor/executor


FROM ${DOCKER_REGISTRY_URL}/${BASE_IMAGE}:${BASE_TAG}

LABEL maintainer="i@pravets.ru" \
      author="Iosif Pravets"

# Прокидываем build-arg версии во второй слой для лейблов
ARG EXECUTOR_VERSION

LABEL executor.version="${EXECUTOR_VERSION}" \
      build.date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      description="1C:Executor ${EXECUTOR_VERSION}"

WORKDIR /tmp

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    locales \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8

ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    PATH="/opt/1C/executor:$PATH"

COPY --from=builder /opt/1C/executor /opt/1C/executor

WORKDIR /work

ENTRYPOINT ["executor"]
CMD ["--help"]
