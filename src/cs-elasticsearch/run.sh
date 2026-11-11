#!/bin/bash
# Запуск Elasticsearch с ограничением кучи JVM.
#
# Эластик не имеет собственного параметра размера кучи: она задаётся опциями JVM,
# поэтому используется стандартный механизм JAVA_TOOL_OPTIONS.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/cs/lib-cs.sh

CS_ES_HEAP="${CS_ES_HEAP:-1g}"

export JAVA_TOOL_OPTIONS="-Xms${CS_ES_HEAP} -Xmx${CS_ES_HEAP} ${JAVA_TOOL_OPTIONS:-}"
log "куча Elasticsearch: ${CS_ES_HEAP}"

exec /usr/local/bin/run-component.sh '1c-cs-elasticsearch-*' "$(elasticsearch_instance_dir)"
