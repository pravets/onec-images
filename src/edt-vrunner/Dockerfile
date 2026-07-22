ARG DOCKER_REGISTRY_URL
ARG EDT_VERSION

# Готовый OneScript из OVM
FROM sleemp/oscript:stable AS oscript

# Финальный образ — EDT из приватного реестра под нужную версию
FROM ${DOCKER_REGISTRY_URL}/edt:${EDT_VERSION}

# Метаданные
ARG EDT_VERSION
ARG BUILD_DATE
LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="edt-vrunner" \
      org.opencontainers.image.description="vanessa-runner поверх edt ${EDT_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ARG MONO_VERSION=6.12.0.182
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       gnupg \
       dirmngr \
       wget \
       locales \
  && gpg --homedir /tmp --batch --yes --no-default-keyring --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
  && echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] http://download.mono-project.com/repo/debian stable-buster/snapshots/$MONO_VERSION main" > /etc/apt/sources.list.d/mono-official-stable.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
       mono-runtime \
       ca-certificates-mono \
       libmono-i18n4.0-all \
       libmono-system-runtime-serialization4.0-cil \
       libicu-dev \
  && rm -rf /etc/apt/sources.list.d/mono-official-stable.list \
  && apt-get update \
  && cert-sync --user /etc/ssl/certs/ca-certificates.crt \
  && rm -rf  \
      /var/lib/apt/lists/* \
      /var/cache/debconf \
  && locale-gen ru_RU.UTF-8 \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8

ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru

WORKDIR /root

COPY --from=oscript /root/.local/share/ovm/stable/ /root/.local/share/ovm/stable/

ENV OSCRIPTBIN=/root/.local/share/ovm/current/bin
ENV PATH="$OSCRIPTBIN:$PATH"

RUN ln -s /root/.local/share/ovm/stable /root/.local/share/ovm/current \
  && opm install vanessa-runner@SNAPSHOT add

ENTRYPOINT ["vrunner"]
CMD ["--help"]
