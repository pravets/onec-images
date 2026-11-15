# cs-elasticsearch — Elasticsearch для 1С:Сервера взаимодействия.
#
# Elasticsearch 5.6 нельзя запускать от root, поэтому процесс идёт от cs.
# Для работы в контейнере нужны: /var/cs на запись (данные и логи) и
# vm.max_map_count >= 262144 на хосте (см. compose/cs/compose.yaml).

ARG CS_BASE_IMAGE=cs-base:30.0.42

FROM ${CS_BASE_IMAGE}

ARG CS_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="cs-elasticsearch" \
      org.opencontainers.image.description="Elasticsearch for 1C:Collaboration server ${CS_VERSION}" \
      org.opencontainers.image.version="${CS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY src/cs-elasticsearch/prepare.sh /usr/local/lib/cs/prepare.d/10-cs-elasticsearch.sh
COPY src/cs-elasticsearch/run.sh /usr/local/bin/run-elasticsearch.sh
RUN chmod +x /usr/local/lib/cs/prepare.d/10-cs-elasticsearch.sh /usr/local/bin/run-elasticsearch.sh

ENV CS_ES_CLUSTER_NAME=1ce-cs \
    CS_ES_NODE_NAME=node-1 \
    CS_ES_HEAP=1g \
    CS_ES_SYSTEM_CALL_FILTER=false

# Транспортный порт (к нему подключается CS) и HTTP API
EXPOSE 9200 9300

CMD ["/usr/local/bin/run-elasticsearch.sh"]
