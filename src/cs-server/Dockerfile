# cs-server — сам 1С:Сервер взаимодействия (компонент cs).
#
# systemd в контейнере не используется: конфигурация пишется утилитой ring,
# а процесс запускается напрямую лаунчером компонента.

ARG CS_BASE_IMAGE=cs-base:30.0.42

FROM ${CS_BASE_IMAGE}

ARG CS_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="cs-server" \
      org.opencontainers.image.description="1C:Collaboration server ${CS_VERSION}" \
      org.opencontainers.image.version="${CS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY src/cs-server/prepare.sh /usr/local/lib/cs/prepare.d/10-cs-server.sh
COPY src/cs-server/bootstrap-cs.sh /usr/local/bin/bootstrap-cs.sh
RUN chmod +x /usr/local/lib/cs/prepare.d/10-cs-server.sh /usr/local/bin/bootstrap-cs.sh

ENV CS_WS_HOSTNAME=0.0.0.0 \
    CS_WS_PORT=8086 \
    CS_WS_WSS=false \
    CS_ADMIN_ADDRESS=0.0.0.0 \
    CS_ADMIN_PORT=8087 \
    CS_ADMIN_USER=admin \
    CS_ADMIN_PASSWORD=admin \
    CS_INTEGRATION_PORT=8443 \
    CS_CONFERENCE_ADDRESS=0.0.0.0 \
    CS_CONFERENCE_PORT=8444 \
    CS_ES_ADDRESSES=elasticsearch:9300 \
    CS_ES_CLUSTER_NAME=1ce-cs \
    CS_HAZELCAST_ADDRESSES=hazelcast \
    CS_HAZELCAST_GROUP_NAME=1ce-cs \
    CS_HAZELCAST_GROUP_PASSWORD=cs-pass \
    CS_LOG_CONSOLE=true \
    CS_LOG_LEVEL=WARN \
    CS_VIDEO_ENABLED=false

# WebSocket для клиентов, административный REST, интеграция, endpoint конференций
EXPOSE 8086 8087 8443 8444

CMD ["/usr/local/bin/run-component.sh", "1c-cs-server-small-*", "/var/cs/cs_instance"]
