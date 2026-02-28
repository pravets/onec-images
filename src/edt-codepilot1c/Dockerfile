ARG DOCKER_REGISTRY_URL
ARG EDT_VERSION

FROM ${DOCKER_REGISTRY_URL}/edt:${EDT_VERSION}

ARG EDT_VERSION
ARG EDT_CODEPILOT_VERSION
ARG BUILD_DATE
ARG MCP_HOST_PORT=8765

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      edt.version="${EDT_VERSION}" \
      edt.codepilot.version="${EDT_CODEPILOT_VERSION}" \
      build.date="${BUILD_DATE}" \
      description="1C:EDT CodePilot1C (EDT ${EDT_VERSION}, CodePilot ${EDT_CODEPILOT_VERSION})"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    xvfb \
    xdg-utils \
    curl \
    unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

ARG EDT_CODEPILOT_VERSION
RUN : "${EDT_CODEPILOT_VERSION:?EDT_CODEPILOT_VERSION argument is required}" \
  && base_version=$(echo "$EDT_CODEPILOT_VERSION" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+') \
  && curl -fSL "https://github.com/ondysss/codepilot1c-edt/releases/download/v${EDT_CODEPILOT_VERSION}/com.codepilot1c.update-${base_version}-SNAPSHOT.zip" \
       -o /tmp/codepilot1c.zip \
  && mkdir -p /tmp/codepilot1c-repo \
  && unzip /tmp/codepilot1c.zip -d /tmp/codepilot1c-repo \
  && xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
       1cedt -clean -purgeHistory \
         -application org.eclipse.equinox.p2.director \
         -noSplash \
         -repository "file:///tmp/codepilot1c-repo" \
         -installIU com.codepilot1c.feature.feature.group \
  && rm -rf /tmp/codepilot1c.zip /tmp/codepilot1c-repo \
  && rm -f /opt/1C/1CE/components/1cedt/configuration/*.log \
  && rm -f /tmp/.X*-lock /tmp/.X11-unix/X*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV MCP_HOST_PORT=0.0.0.0
ENV MCP_HOST_PORT=8765
ENV WORKSPACE_DIR=/edt

EXPOSE ${MCP_HOST_PORT}

VOLUME ["/edt"]
WORKDIR /edt

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
