ARG DOCKER_REGISTRY_URL=library
ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=24.04

FROM ${DOCKER_REGISTRY_URL}/${BASE_IMAGE}:${BASE_TAG}
LABEL maintainer="Iosif Pravets <i@pravets.ru>"

# mono and oscript dependencies
ARG MONO_VERSION=6.12.0.182

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
RUN  locale-gen ru_RU.UTF-8 \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8

# locale
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# oscript
ARG OVM_VERSION=1.6.1
ARG OSCRIPT_VERSION

RUN wget https://github.com/oscript-library/ovm/releases/download/v${OVM_VERSION}/ovm.exe \
  && mv ovm.exe /usr/local/bin/ \
  && echo 'mono /usr/local/bin/ovm.exe "$@"' | tee /usr/local/bin/ovm \
  && chmod +x /usr/local/bin/ovm \
  && ovm install ${OSCRIPT_VERSION} \
  && ovm use ${OSCRIPT_VERSION}

ENV OSCRIPTBIN=/root/.local/share/ovm/current/bin
ENV PATH="$OSCRIPTBIN:$PATH"

ENTRYPOINT ["oscript"]