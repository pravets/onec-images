ARG DOCKER_REGISTRY_URL
ARG EDT_VERSION
ARG BUILD_DATE

FROM ${DOCKER_REGISTRY_URL}/edt:${EDT_VERSION}

ARG EDT_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      edt.version="${EDT_VERSION}" \
      build.date="${BUILD_DATE}" \
      description="1C:EDT CLI ${EDT_VERSION}"

VOLUME ["/edt"]

WORKDIR /edt

ENTRYPOINT ["1cedtcli"]
