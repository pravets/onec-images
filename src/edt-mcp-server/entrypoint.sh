#!/bin/bash
set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/edt}"
MCP_SERVER_PORT="${MCP_SERVER_PORT:-8765}"

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

echo "Starting EDT MCP Server (workspace=${WORKSPACE_DIR}, port=${MCP_SERVER_PORT})"
exec xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
  1cedt -nosplash -consoleLog -noexit -data "$WORKSPACE_DIR" \
  "$@"
