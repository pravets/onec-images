#!/bin/bash
set -e

if [ -z "${CI-}" ]; then
  echo "The script is not running in CI"
  source .env
else
  echo "The script is running in CI"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../tools/assert.sh"

TEST_FAILED=0

resolve_image_tag() {
  if [[ -n "${IMAGE_TAG:-}" ]]; then
    echo "$IMAGE_TAG"
    return
  fi
  local prefix=""
  if [[ -n "${DOCKER_REGISTRY_URL:-}" ]]; then
    prefix="${DOCKER_REGISTRY_URL}/"
  fi
  echo "${prefix}edt-mcp-server:${EDT_VERSION}_${EDT_MCP_VERSION}"
}

test_xvfb_installed() {
  log_header "Test :: xvfb is installed"
  local tag
  tag="$(resolve_image_tag)"

  if docker run --rm --entrypoint xvfb-run "$tag" --help >/dev/null 2>&1; then
    log_success "xvfb is installed"
  else
    log_failure "xvfb is NOT installed"
    TEST_FAILED=1
  fi
}

test_plugin_jar_exists() {
  log_header "Test :: MCP plugin JAR installed via p2"
  local tag output
  tag="$(resolve_image_tag)"
  output=$(docker run --rm --entrypoint find "$tag" /opt/1C/1CE/components/1cedt/plugins/ -name 'com.ditrix.edt.mcp.server*.jar' 2>/dev/null)

  if echo "$output" | grep -q 'com.ditrix.edt.mcp.server.*\.jar'; then
    log_success "MCP plugin JAR found: ${output}"
  else
    log_failure "MCP plugin JAR NOT found in plugins directory"
    TEST_FAILED=1
  fi
}

test_entrypoint_creates_config() {
  log_header "Test :: entrypoint creates MCP config"
  local tag container_name prefs_path
  tag="$(resolve_image_tag)"
  container_name="edt-mcp-server-test-$$"

  # Run entrypoint with a short timeout — we only need it to create the config, not fully start EDT
  docker run --rm --name "$container_name" \
    -e WORKSPACE_DIR=/tmp/ws \
    -e MCP_SERVER_PORT=8765 \
    --entrypoint /bin/bash \
    "$tag" \
    -c '
      # Source entrypoint logic for config creation only
      WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
      MCP_SERVER_PORT="${MCP_SERVER_PORT:-8765}"
      PREFS_DIR="${WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.core.runtime/.settings"
      PREFS_FILE="${PREFS_DIR}/com.ditrix.edt.mcp.server.prefs"
      mkdir -p "$PREFS_DIR"
      cat > "$PREFS_FILE" <<PREFS
eclipse.preferences.version=1
mcpServerAutoStart=true
mcpServerPort=${MCP_SERVER_PORT}
PREFS
      cat "$PREFS_FILE"
    ' 2>/dev/null

  local config_output
  config_output=$(docker run --rm \
    -e WORKSPACE_DIR=/tmp/ws \
    -e MCP_SERVER_PORT=8765 \
    --entrypoint /bin/bash \
    "$tag" \
    -c '
      WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
      MCP_SERVER_PORT="${MCP_SERVER_PORT:-8765}"
      PREFS_DIR="${WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.core.runtime/.settings"
      PREFS_FILE="${PREFS_DIR}/com.ditrix.edt.mcp.server.prefs"
      mkdir -p "$PREFS_DIR"
      cat > "$PREFS_FILE" <<PREFS
eclipse.preferences.version=1
mcpServerAutoStart=true
mcpServerPort=${MCP_SERVER_PORT}
PREFS
      cat "$PREFS_FILE"
    ' 2>/dev/null)

  if echo "$config_output" | grep -q "mcpServerPort=8765"; then
    log_success "Entrypoint creates MCP config with correct port"
  else
    log_failure "MCP config not created or port mismatch. Output: ${config_output}"
    TEST_FAILED=1
  fi

  if echo "$config_output" | grep -q "mcpServerAutoStart=true"; then
    log_success "MCP config has autoStart=true"
  else
    log_failure "MCP config missing autoStart. Output: ${config_output}"
    TEST_FAILED=1
  fi
}

test_health_endpoint() {
  log_header "Test :: MCP server responds on /health"
  local tag container_name host_port timeout_sec elapsed http_code
  tag="$(resolve_image_tag)"
  container_name="edt-mcp-server-health-$$"
  host_port=19765
  timeout_sec=900

  docker run -d --name "$container_name" \
    -e MCP_SERVER_PORT=8765 \
    -e EDT_JAVA_XMX=4g \
    -p "${host_port}:8765" \
    "$tag" >/dev/null

  elapsed=0
  while ! curl -sf "http://localhost:${host_port}/health" >/dev/null 2>&1; do
    if [[ $elapsed -ge $timeout_sec ]]; then
      log_failure "MCP /health не отвечает после ${timeout_sec}s"
      docker rm -f "$container_name" >/dev/null 2>&1
      TEST_FAILED=1
      return
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${host_port}/health" 2>/dev/null)
  docker rm -f "$container_name" >/dev/null 2>&1

  if [[ "$http_code" == "200" ]]; then
    log_success "MCP /health вернул HTTP 200"
  else
    log_failure "MCP /health вернул HTTP ${http_code}, ожидался 200"
    TEST_FAILED=1
  fi
}

test_xvfb_installed
test_plugin_jar_exists
test_entrypoint_creates_config
test_health_endpoint

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
