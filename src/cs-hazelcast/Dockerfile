# cs-hazelcast — Hazelcast для 1С:Сервера взаимодействия.

ARG CS_BASE_IMAGE=cs-base:30.0.42

FROM ${CS_BASE_IMAGE}

ARG CS_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="cs-hazelcast" \
      org.opencontainers.image.description="Hazelcast for 1C:Collaboration server ${CS_VERSION}" \
      org.opencontainers.image.version="${CS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY src/cs-hazelcast/prepare.sh /usr/local/lib/cs/prepare.d/10-cs-hazelcast.sh
RUN chmod +x /usr/local/lib/cs/prepare.d/10-cs-hazelcast.sh

# Пароль группы задаётся при запуске (CS_HAZELCAST_GROUP_PASSWORD) и не хранится
# в метаданных образа. Значение по умолчанию для разработки — в prepare.sh.
ENV CS_HAZELCAST_GROUP_NAME=1ce-cs

EXPOSE 5701

CMD ["/usr/local/bin/run-component.sh", "1c-cs-hazelcast-*", "/var/cs/hazelcast_instance"]
