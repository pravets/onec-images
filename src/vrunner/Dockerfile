ARG DOCKER_REGISTRY_URL
ARG ONEC_VERSION
FROM sleemp/oscript:stable AS oscript

# Финальный образ — платформа 1С из приватного реестра под нужную версию
FROM ${DOCKER_REGISTRY_URL}/onec-platform:${ONEC_VERSION}

# Метаданные
ARG ONEC_VERSION
ARG BUILD_DATE
LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="vrunner" \
      org.opencontainers.image.description="vrunner поверх onec-platform ${ONEC_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ARG MONO_VERSION=6.12.0.182
ARG OVM_VERSION=1.6.1
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       gnupg \
       dirmngr \
       wget \
       locales \
  && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
  && echo "deb http://download.mono-project.com/repo/debian stable-buster/snapshots/$MONO_VERSION main" > /etc/apt/sources.list.d/mono-official-stable.list \
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

WORKDIR /home/usr1cv8
USER usr1cv8

COPY --chown=usr1cv8:grp1cv8 --from=oscript /root/.local/share/ovm/stable/ /home/usr1cv8/.local/share/ovm/stable/

ENV OSCRIPTBIN=/home/usr1cv8/.local/share/ovm/current/bin
ENV PATH="$OSCRIPTBIN:$PATH"

RUN ln -s /home/usr1cv8/.local/share/ovm/stable /home/usr1cv8/.local/share/ovm/current \
  && opm install vanessa-runner add

ENTRYPOINT ["vrunner"]
CMD ["--help"]
