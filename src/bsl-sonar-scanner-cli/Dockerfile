# bsl-sonar-scanner-cli — SonarScanner CLI + файлы синтакс-помощника 1С.
#
# Берём за основу sonarsource/sonar-scanner-cli фиксированной версии
# (переопределяется build-arg SONAR_SCANNER_VERSION) и докидываем файлы
# синтакс-помощника 1С (shcntx_*.hbk, shlang_*.hbk) из образа onec-platform
# по тем же путям, что они лежат в исходном образе.

ARG SONAR_SCANNER_VERSION=12.1.0.3233_8.0.1
# Полный тег базового образа onec-platform (резолвится в build-скрипте:
# локальный образ без префикса -> с префиксом реестра -> pull -> локальная сборка).
# Дефолт — только чтобы избежать предупреждения BuildKit; реальное значение
# всегда передаётся из build-скрипта.
ARG ONEC_BASE_IMAGE=onec-platform:8.3.27.2214

# Стадия-источник файлов синтакс-помощника.
# ВАЖНО: стадия с параметризованным FROM должна идти ПЕРВОЙ — иначе BuildKit
# падает с "circular dependency detected on stage".
FROM ${ONEC_BASE_IMAGE} AS onec-base

FROM sonarsource/sonar-scanner-cli:${SONAR_SCANNER_VERSION}

# Версия образа onec-platform, из которого берём hbk-файлы.
# Прибита молотком (последняя актуальная), переопределяется при сборке.
ARG ONEC_VERSION=8.3.27.2214
ARG BUILD_DATE
ARG SONAR_SCANNER_VERSION

LABEL maintainer="Iosif Pravets <i@pravets.ru>" \
      org.opencontainers.image.title="bsl-sonar-scanner-cli" \
      org.opencontainers.image.description="SonarScanner CLI ${SONAR_SCANNER_VERSION} + 1C:Enterprise syntax helper (shcntx_*.hbk, shlang_*.hbk) from onec-platform ${ONEC_VERSION}" \
      org.opencontainers.image.version="${ONEC_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

# Копируем файлы синтакс-помощника по тем же путям, что в исходном образе onec-platform.
# Пользователь сканера (scanner-cli) читает их как обычный непривилегированный процесс.
COPY --from=onec-base \
     /opt/1cv8/x86_64/${ONEC_VERSION}/shcntx_root.hbk \
     /opt/1cv8/x86_64/${ONEC_VERSION}/shcntx_ru.hbk \
     /opt/1cv8/x86_64/${ONEC_VERSION}/shlang_root.hbk \
     /opt/1cv8/x86_64/${ONEC_VERSION}/shlang_ru.hbk \
     /opt/1cv8/x86_64/${ONEC_VERSION}/
