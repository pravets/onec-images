ARG DOCKER_REGISTRY_URL
ARG EDT_VERSION

FROM ${DOCKER_REGISTRY_URL}/edt:${EDT_VERSION}

ARG EDT_VERSION
ARG EDT_CODEPILOT_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      edt.version="${EDT_VERSION}" \
      edt.codepilot.version="${EDT_CODEPILOT_VERSION}" \
      build.date="${BUILD_DATE}" \
      description="1C:EDT CodePilot1C MCP Server (EDT ${EDT_VERSION}, CodePilot ${EDT_CODEPILOT_VERSION})"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    curl \
    unzip \
    uuid-runtime \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

ARG EDT_CODEPILOT_VERSION
RUN : "${EDT_CODEPILOT_VERSION:?EDT_CODEPILOT_VERSION argument is required}" \
  && base_version=$(echo "$EDT_CODEPILOT_VERSION" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+') \
  && curl -fSL "https://github.com/ondysss/codepilot1c-edt/releases/download/v${EDT_CODEPILOT_VERSION}/com.codepilot1c.update-${base_version}-SNAPSHOT.zip" \
       -o /tmp/codepilot1c.zip \
  && mkdir -p /tmp/codepilot1c-repo \
  && unzip /tmp/codepilot1c.zip -d /tmp/codepilot1c-repo \
  && 1cedt -clean -purgeHistory \
         -application org.eclipse.equinox.p2.director \
         -noSplash \
         -repository "file:///tmp/codepilot1c-repo" \
         -installIU com.codepilot1c.feature.feature.group \
  && rm -rf /tmp/codepilot1c.zip /tmp/codepilot1c-repo \
  && rm -f /opt/1C/1CE/components/1cedt/configuration/*.log

# Патчим bundles.info для autoStart плагина CodePilot1C.
# com.codepilot1c.core должен стартовать автоматически (eclipse.ignoreApp=true, без workbench).
RUN BUNDLES_INFO=/opt/1C/1CE/components/1cedt/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info \
  && sed -i 's/^\(com\.codepilot1c\.core,[^,]*,[^,]*,4\),false$/\1,true/' "$BUNDLES_INFO" \
  && echo "Updated bundles.info:" && grep codepilot "$BUNDLES_INFO"

# Записываем параметры CodePilot1C MCP в 1cedt.ini.
# Важно: все JVM-параметры должны быть в ini, а не передаваться через -vmargs
# в командной строке — иначе Eclipse launcher заменит ими весь блок -vmargs из ini.
RUN printf '%s\n' \
      '-Dcodepilot.mcp.enabled=true' \
      '-Dcodepilot.mcp.host.http.enabled=true' \
      '-Dcodepilot.mcp.host.http.bindAddress=0.0.0.0' \
#      '-Dcodepilot.mcp.host.auth.mode=BEARER_ONLY' \
      '-Dcodepilot.mcp.host.http.port=8765' \
      '-Dcodepilot.mcp.host.policy.defaultMutationDecision=ALLOW' \
      '-Dcodepilot.mcp.host.policy.exposedTools=*' \
      '-Declipse.ignoreApp=true' \
      '-Dosgi.noShutdown=true' \
      >> /opt/1C/1CE/components/1cedt/1cedt.ini

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY manage_codepilot_token.sh /usr/local/bin/manage_codepilot_token.sh
COPY manage_xmx.sh /usr/local/bin/manage_xmx.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
  && chmod +x /usr/local/bin/manage_codepilot_token.sh \
  && chmod +x /usr/local/bin/manage_xmx.sh

ENV WORKSPACE_DIR=/edt

EXPOSE 8765

VOLUME ["/edt"]
WORKDIR /edt

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
