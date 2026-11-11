# cs-site — сайт для внешних пользователей системы взаимодействия.
#
# Компонент 1c-cs-site в образе cs-base уже распакован установщиком в статическое
# SPA (index.html, js, шрифты, изображения, config.json), поэтому Java и
# инсталлятор не нужны: статика копируется из cs-base и отдаётся nginx.
# Адрес сервера взаимодействия подставляется в config.json при старте контейнера.

ARG CS_BASE_IMAGE=cs-base:30.0.42

# Стадия-источник статики. ВАЖНО: стадия с параметризованным FROM должна идти
# ПЕРВОЙ — иначе BuildKit падает с "circular dependency detected on stage".
FROM ${CS_BASE_IMAGE} AS payload

RUN mkdir -p /payload \
    && cp -a /opt/1C/1CE/components/1c-cs-site-*/. /payload/ \
    && test -f /payload/index.html \
    && test -f /payload/config.json

FROM nginx:1.27-alpine

ARG CS_VERSION
ARG BUILD_DATE

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="cs-site" \
      org.opencontainers.image.description="1C:Collaboration server external users site (1c-cs-site) for CS ${CS_VERSION}" \
      org.opencontainers.image.version="${CS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY --from=payload /payload /usr/share/nginx/html
COPY src/cs-common/nginx-spa.conf /etc/nginx/conf.d/default.conf
COPY src/cs-common/render-site-config.sh /docker-entrypoint.d/40-cs-site-config.sh
RUN chmod +x /docker-entrypoint.d/40-cs-site-config.sh

# Адрес сервера взаимодействия, который увидит браузер внешнего пользователя
ENV CS_PUBLIC_WS_URL=wss://cs.example.com \
    CS_VAPID_PUBLIC_KEY=

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1/index.html > /dev/null || exit 1
