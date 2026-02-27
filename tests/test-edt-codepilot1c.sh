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

test_entrypoint_has_jvm_args() {
  log_header "Test :: entrypoint passes CodePilot1C JVM system properties"
  local tag output
  tag="$(resolve_image_tag)"

  output=$(docker run --rm \
    --entrypoint cat \
    "$tag" \
    /usr/local/bin/entrypoint.sh 2>/dev/null)

  if echo "$output" | grep -q "codepilot.mcp.host.enabled=true"; then
    log_success "entrypoint contains -Dcodepilot.mcp.host.enabled=true"
  else
    log_failure "entrypoint is missing -Dcodepilot.mcp.host.enabled=true"
    TEST_FAILED=1
  fi

  if echo "$output" | grep -q "codepilot.mcp.host.http.port"; then
    log_success "entrypoint contains -Dcodepilot.mcp.host.http.port"
  else
    log_failure "entrypoint is missing -Dcodepilot.mcp.host.http.port"
    TEST_FAILED=1
  fi
}

test_health_endpoint() {
  log_header "Test :: CodePilot1C MCP host responds on /health"
  local tag container_name host_port timeout_sec elapsed http_code
  tag="$(resolve_image_tag)"
  container_name="edt-codepilot1c-health-$$"
  host_port=19766
  timeout_sec=900

  docker run -d --name "$container_name" \
    -e MCP_HOST_PORT=8765 \
    -e EDT_JAVA_XMX=4g \
    -p "${host_port}:8765" \
    "$tag" >/dev/null

  elapsed=0
  while ! curl -sf "http://localhost:${host_port}/health" >/dev/null 2>&1; do
    if [[ $elapsed -ge $timeout_sec ]]; then
      log_failure "CodePilot1C /health не отвечает после ${timeout_sec}s"
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
    log_success "CodePilot1C /health вернул HTTP 200"
  else
    log_failure "CodePilot1C /health вернул HTTP ${http_code}, ожидался 200"
    TEST_FAILED=1
  fi
}

test_xvfb_installed
test_plugin_jar_exists
test_entrypoint_has_jvm_args
test_health_endpoint

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
