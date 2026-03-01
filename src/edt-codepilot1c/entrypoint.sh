#!/bin/bash
set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/edt}"
EDT_JAVA_XMX="${EDT_JAVA_XMX:-12g}"
INI_FILE="/opt/1C/1CE/components/1cedt/1cedt.ini"

# Управление bearer токеном для MCP API
/usr/local/bin/manage_codepilot_token.sh "$INI_FILE"

# Обновляем -Xmx в ini, не передавая -vmargs в командной строке.
# Eclipse launcher: если -vmargs передаётся в cmdline, он ПОЛНОСТЬЮ заменяет
# блок -vmargs из .ini, и все -Dcodepilot.* настройки там игнорируются.
/usr/local/bin/manage_xmx.sh "$INI_FILE"

echo "Starting EDT CodePilot1C MCP Server (workspace=${WORKSPACE_DIR}, Xmx=${EDT_JAVA_XMX})"
exec 1cedt -nosplash -consoleLog -noexit -data "$WORKSPACE_DIR" \
  "$@"
