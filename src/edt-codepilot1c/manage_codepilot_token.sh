#!/bin/bash
set -e

INI_FILE="${1:-/opt/1C/1CE/components/1cedt/1cedt.ini}"
TOKEN_PARAM_PREFIX="-Dcodepilot.mcp.host.http.bearerToken="

if [ -n "${EDT_CODEPILOT_BEARERTOKEN:-}" ]; then
  # Токен задан в env — обновить/добавить в ini
  if grep -q "^${TOKEN_PARAM_PREFIX}" "$INI_FILE" 2>/dev/null; then
    # Заменить существующий токен
    sed -i "s|^${TOKEN_PARAM_PREFIX}.*|${TOKEN_PARAM_PREFIX}${EDT_CODEPILOT_BEARERTOKEN}|" "$INI_FILE"
    echo "BearerToken updated from environment variable"
  else
    # Добавить токен
    echo "${TOKEN_PARAM_PREFIX}${EDT_CODEPILOT_BEARERTOKEN}" >> "$INI_FILE"
    echo "BearerToken added from environment variable"
  fi
else
  # Токен не задан — проверить наличие в ini
  if grep -q "^${TOKEN_PARAM_PREFIX}" "$INI_FILE" 2>/dev/null; then
    echo "BearerToken already configured in 1cedt.ini"
  else
    # Сгенерировать новый токен
    GENERATED_TOKEN=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    echo "${TOKEN_PARAM_PREFIX}${GENERATED_TOKEN}" >> "$INI_FILE"
    echo "=============================================="
    echo "Generated CodePilot1C MCP BearerToken:"
    echo "${GENERATED_TOKEN}"
    echo "=============================================="
    echo "Set EDT_CODEPILOT_BEARERTOKEN environment variable to use a custom token"
  fi
fi
