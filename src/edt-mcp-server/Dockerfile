ARG DOCKER_REGISTRY_URL
ARG EDT_VERSION

FROM ${DOCKER_REGISTRY_URL}/edt:${EDT_VERSION}

ARG EDT_VERSION
ARG EDT_MCP_VERSION
ARG BUILD_DATE
ARG MCP_SERVER_PORT=8765

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      edt.version="${EDT_VERSION}" \
      edt.mcp.version="${EDT_MCP_VERSION}" \
      build.date="${BUILD_DATE}" \
      description="1C:EDT MCP Server (EDT ${EDT_VERSION}, MCP ${EDT_MCP_VERSION})"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    xvfb \
    curl \
    unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

ARG EDT_MCP_VERSION
RUN : "${EDT_MCP_VERSION:?EDT_MCP_VERSION argument is required}" \
  && curl -fSL "https://github.com/DitriXNew/EDT-MCP/releases/download/v${EDT_MCP_VERSION}/MCP-EDT.v${EDT_MCP_VERSION}.zip" \
       -o /tmp/mcp-edt.zip \
  && mkdir -p /tmp/mcp-repo \
  && unzip /tmp/mcp-edt.zip -d /tmp/mcp-repo \
  && xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
       1cedt -clean -purgeHistory \
         -application org.eclipse.equinox.p2.director \
         -noSplash \
         -repository "file:///tmp/mcp-repo" \
         -installIU com.ditrix.edt.mcp.server.feature.feature.group \
  && rm -rf /tmp/mcp-edt.zip /tmp/mcp-repo \
  && rm -f /opt/1C/1CE/components/1cedt/configuration/*.log \
  && rm -f /tmp/.X*-lock /tmp/.X11-unix/X*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV MCP_SERVER_PORT=8765
ENV WORKSPACE_DIR=/edt

EXPOSE ${MCP_SERVER_PORT}

VOLUME ["/edt"]
WORKDIR /edt

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
