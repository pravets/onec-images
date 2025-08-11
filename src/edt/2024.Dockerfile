# Используем базовый образ для скачивания
ARG DOWNLOADER_REGISTRY_URL=sleemp
ARG DOWNLOADER_IMAGE=onec-installer-downloader
ARG DOWNLOADER_TAG=latest

ARG BASE_IMAGE=eclipse-temurin
ARG BASE_TAG=17
ARG DOCKER_REGISTRY_URL=library

FROM ${DOWNLOADER_REGISTRY_URL}/${DOWNLOADER_IMAGE}:${DOWNLOADER_TAG} AS downloader

ARG EDT_VERSION
RUN : "${EDT_VERSION:?EDT_VERSION argument is required}"

WORKDIR /tmp

RUN --mount=type=secret,id=onec_username \
    --mount=type=secret,id=onec_password \
    export YARD_RELEASES_USER=$(cat /run/secrets/onec_username) && \
    export YARD_RELEASES_PWD=$(cat /run/secrets/onec_password) && \
    /app/downloader.sh edt "$EDT_VERSION"

FROM ${DOCKER_REGISTRY_URL}/${BASE_IMAGE}:${BASE_TAG} AS base

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    # edt dependencies
    libgtk-3-0 \
    locales \
    ca-certificates \
    openjfx \
    libopenjfx-java \
  && apt-get clean \
  && rm -rf  \
    /var/lib/apt/lists/* \
    /var/cache/debconf \
    /tmp/* \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8

FROM base AS installer

LABEL maintainer="Iosif Pravets <i@pravets.ru>"

ARG EDT_VERSION
ARG downloads=downloads/DevelopmentTools10/${EDT_VERSION}

WORKDIR /tmp

# Install EDT
COPY --from=downloader /tmp/${downloads} /tmp/${downloads}

WORKDIR /tmp/${downloads}

ARG EDT_DISABLE_EDITING_VERSION=0.6.0.20250410-2002
RUN chmod +x ./1ce-installer-cli \
  && ./1ce-installer-cli install all --ignore-hardware-checks --ignore-signature-warnings \
  && RING_PATH="$(find /opt/1C/1CE -type f -name ring -print -quit)" \
  && EDT_PATH="$(find /opt/1C/1CE -type f -name 1cedt -print -quit)" \
  && [ -n "$RING_PATH" ] \
  && [ -n "$EDT_PATH" ] \
  && ln -sfn "$(dirname "$RING_PATH")" /opt/1C/1CE/components/1c-enterprise-ring \
  && ln -sfn "$(dirname "$EDT_PATH")" /opt/1C/1CE/components/1cedt \
  && sed -i -e 's/4096m/12288m/g' "$(dirname "$EDT_PATH")"/1cedt.ini \
  && sed -i '/^-Xmx/a --add-modules=javafx.controls,javafx.fxml,javafx.web\n--module-path=/usr/share/openjfx/lib' "$(dirname "$EDT_PATH")"/1cedt.ini \
  && "$(dirname "$EDT_PATH")"/1cedt -clean -purgeHistory -application org.eclipse.equinox.p2.director -noSplash -repository https://marmyshev.gitlab.io/edt-editing/update -installIU org.mard.dt.editing.feature.feature.group/${EDT_DISABLE_EDITING_VERSION} \
  && rm -f "$(dirname "$EDT_PATH")"/configuration/*.log \
  && rm -rf "$(dirname "$EDT_PATH")"/configuration/org.eclipse.core.runtime \
  && rm -rf "$(dirname "$EDT_PATH")"/configuration/org.eclipse.osgi \
  && rm -rf "$(dirname "$EDT_PATH")"/plugin-development \
  && rm -f "$(dirname "$EDT_PATH")"/plugins/com._1c.g5.v8.dt.platform.doc_*.jar \
  && rm -f "$(dirname "$EDT_PATH")"/plugins/com._1c.g5.v8.dt.platform.doc_v8_*.jar \
  && rm -f "$(dirname "$EDT_PATH")"/plugins/com._1c.g5.v8.dt.product.doc_*.jar \
  && rm -f "$(dirname "$EDT_PATH")"/plugins/org.eclipse.egit.doc_*.jar \
  && rm -f "$(dirname "$EDT_PATH")"/plugins/org.eclipse.platform.doc_*.jar \
  && rm -rf /tmp/*

FROM base

ARG EDT_VERSION
RUN : "${EDT_VERSION:?EDT_VERSION argument is required}"

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      edt.version="${EDT_VERSION}" \
      build.date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      description="1C:Enterprise Development Tools ${EDT_VERSION}"

# Установка переменных окружения для корректной работы локали
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Copy EDT
COPY --from=installer /opt/1C/1CE /opt/1C/1CE

ENV PATH="/opt/1C/1CE/components/1c-enterprise-ring:/opt/1C/1CE/components/1cedt:$PATH"

# Обеспечить единообразие имён CLI (1cedtcli и 1cedtcli.sh)
COPY scripts/ensure_edtcli_symlink.sh /usr/local/bin/ensure_edtcli_symlink.sh
RUN chmod +x /usr/local/bin/ensure_edtcli_symlink.sh \
  && /usr/local/bin/ensure_edtcli_symlink.sh --dir /opt/1C/1CE/components/1cedt \
  && rm -f /usr/local/bin/ensure_edtcli_symlink.sh