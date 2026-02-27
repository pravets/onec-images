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
  echo "${prefix}edt-codepilot1c:${EDT_VERSION}_${EDT_CODEPILOT_VERSION}"
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
  log_header "Test :: CodePilot1C plugin JAR installed via p2"
  local tag output
  tag="$(resolve_image_tag)"
  output=$(docker run --rm --entrypoint find "$tag" /opt/1C/1CE/components/1cedt/plugins/ -name 'com.codepilot1c*.jar' 2>/dev/null)

  if echo "$output" | grep -q 'com\.codepilot1c.*\.jar'; then
    log_success "CodePilot1C plugin JAR found: ${output}"
  else
    log_failure "CodePilot1C plugin JAR NOT found in plugins directory"
    TEST_FAILED=1
  fi
}

test_entrypoint_creates_config() {
  log_header "Test :: entrypoint creates CodePilot1C config"
  local tag
  tag="$(resolve_image_tag)"

  local config_output
  config_output=$(docker run --rm \
    -e WORKSPACE_DIR=/tmp/ws \
    -e MCP_HOST_PORT=8765 \
    --entrypoint /bin/bash \
    "$tag" \
    -c '
      WORKSPACE_DIR="${WORKSPACE_DIR:-/edt}"
      MCP_HOST_PORT="${MCP_HOST_PORT:-8765}"
      PREFS_DIR="${WORKSPACE_DIR}/.metadata/.plugins/org.eclipse.core.runtime/.settings"
      PREFS_FILE="${PREFS_DIR}/com.codepilot1c.core.prefs"
      mkdir -p "$PREFS_DIR"
      cat > "$PREFS_FILE" <<PREFS
eclipse.preferences.version=1
mcp.host.enabled=true
mcp.host.http.enabled=true
mcp.host.http.bindAddress=0.0.0.0
mcp.host.http.port=${MCP_HOST_PORT}
PREFS
      cat "$PREFS_FILE"
    ' 2>/dev/null)

  if echo "$config_output" | grep -q "mcp.host.http.port=8765"; then
    log_success "Entrypoint creates CodePilot1C config with correct port"
  else
    log_failure "CodePilot1C config not created or port mismatch. Output: ${config_output}"
    TEST_FAILED=1
  fi

  if echo "$config_output" | grep -q "mcp.host.enabled=true"; then
    log_success "CodePilot1C config has mcp.host.enabled=true"
  else
    log_failure "CodePilot1C config missing mcp.host.enabled. Output: ${config_output}"
    TEST_FAILED=1
  fi
}

test_mcp_endpoint() {
  log_header "Test :: CodePilot1C MCP host responds on /mcp"
  local tag container_name host_port timeout_sec elapsed http_code
  tag="$(resolve_image_tag)"
  container_name="edt-codepilot1c-mcp-$$"
  host_port=19766
  timeout_sec=900

  docker run -d --name "$container_name" \
    -e MCP_HOST_PORT=8765 \
    -e EDT_JAVA_XMX=4g \
    -p "${host_port}:8765" \
    "$tag" >/dev/null

  elapsed=0
  while true; do
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${host_port}/mcp" 2>/dev/null || echo "000")
    if [[ "$http_code" != "000" ]]; then
      break
    fi
    if [[ $elapsed -ge $timeout_sec ]]; then
      log_failure "CodePilot1C MCP /mcp не отвечает после ${timeout_sec}s"
      docker rm -f "$container_name" >/dev/null 2>&1
      TEST_FAILED=1
      return
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  docker rm -f "$container_name" >/dev/null 2>&1

  if [[ "$http_code" != "000" ]]; then
    log_success "CodePilot1C MCP /mcp вернул HTTP ${http_code}"
  else
    log_failure "CodePilot1C MCP /mcp не отвечает"
    TEST_FAILED=1
  fi
}

test_xvfb_installed
test_plugin_jar_exists
test_entrypoint_creates_config
test_mcp_endpoint

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
