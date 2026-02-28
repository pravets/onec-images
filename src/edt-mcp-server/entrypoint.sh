#!/bin/bash
set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/edt}"
MCP_SERVER_PORT="${MCP_SERVER_PORT:-8765}"
EDT_JAVA_XMX="${EDT_JAVA_XMX:-12g}"

PREFS_DIR="${WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.core.runtime/.settings"
PREFS_FILE="${PREFS_DIR}/com.ditrix.edt.mcp.server.prefs"

if [ ! -f "$PREFS_FILE" ]; then
  mkdir -p "$PREFS_DIR"
  cat > "$PREFS_FILE" <<EOF
eclipse.preferences.version=1
mcpServerAutoStart=true
mcpServerPort=${MCP_SERVER_PORT}
EOF
  echo "MCP config created: ${PREFS_FILE} (port=${MCP_SERVER_PORT})"
else
    echo "MCP config already exists: ${PREFS_FILE}"
fi

# Очистка stale X lock-файлов
rm -f /tmp/.X*-lock /tmp/.X11-unix/X*

# Запуск Xvfb напрямую, без xvfb-run.
# xvfb-run использует wait + SIGUSR1 для ожидания готовности Xvfb,
# но этот механизм ломается когда скрипт является PID 1 контейнера
# (ядро Linux не прерывает wait сигналом для PID 1).
DISPLAY_NUM=99
export DISPLAY=:${DISPLAY_NUM}

Xvfb ":${DISPLAY_NUM}" -screen 0 1024x768x24 -ac -nolisten tcp >/dev/null 2>&1 &
XVFB_PID=$!

# Ждём готовности Xvfb
sleep 1

if ! kill -0 "$XVFB_PID" 2>/dev/null; then
  echo "ERROR: Xvfb failed to start" >&2
  exit 1
fi

# Завершаем Xvfb при выходе
cleanup() {
  kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting EDT MCP Server (workspace=${WORKSPACE_DIR}, port=${MCP_SERVER_PORT}, Xmx=${EDT_JAVA_XMX})"
exec 1cedt -nosplash -consoleLog -noexit -data "$WORKSPACE_DIR" \
  "$@" \
  -vmargs "-Xmx${EDT_JAVA_XMX}"
