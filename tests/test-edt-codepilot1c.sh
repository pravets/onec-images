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

test_ini_contains_mcp_settings() {
  log_header "Test :: 1cedt.ini contains CodePilot1C MCP settings"
  local tag ini_content
  tag="$(resolve_image_tag)"
  ini_content=$(docker run --rm --entrypoint cat "$tag" /opt/1C/1CE/components/1cedt/1cedt.ini 2>/dev/null)

  local all_ok=1
  for key in \
    'codepilot.mcp.enabled=true' \
    'codepilot.mcp.host.http.enabled=true' \
    'codepilot.mcp.host.http.bindAddress=0.0.0.0' \
    'codepilot.mcp.host.http.port=8765' \
    'codepilot.mcp.host.policy.defaultMutationDecision=ALLOW' \
    'codepilot.mcp.host.policy.exposedTools=*' \
    'eclipse.ignoreApp=true' \
    'osgi.noShutdown=true' ; do
    if ! echo "$ini_content" | grep -qF "$key"; then
      log_failure "Missing in 1cedt.ini: ${key}"
      all_ok=0
    fi
  done

  if [[ $all_ok -eq 1 ]]; then
    log_success "All CodePilot1C MCP settings found in 1cedt.ini"
  else
    TEST_FAILED=1
  fi
}
test_health_endpoint() {
  log_header "Test :: CodePilot1C MCP health endpoint returns HTTP 200"
  local tag container_name host_port timeout_sec elapsed http_code
  tag="$(resolve_image_tag)"
  container_name="edt-codepilot1c-mcp-test"
  host_port=19766
  timeout_sec=900

  docker rm -f "$container_name" >/dev/null 2>&1 || true

  docker run -d --name "$container_name" \
    -e EDT_JAVA_XMX=4g \
    -p "${host_port}:8765" \
    "$tag" >/dev/null

  elapsed=0
  while true; do
    # Проверяем, что контейнер ещё работает
    if ! docker inspect --format '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q 'true'; then
      log_failure "Контейнер ${container_name} завершился неожиданно. Логи:"
      docker logs "$container_name" >&2 || true
      docker rm -f "$container_name" >/dev/null 2>&1 || true
      TEST_FAILED=1
      return
    fi

    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      "http://localhost:${host_port}/health" 2>/dev/null) || true
    if [[ "$http_code" == "200" ]]; then
      break
    fi
    if [[ $elapsed -ge $timeout_sec ]]; then
      log_failure "CodePilot1C /health не вернул HTTP 200 после ${timeout_sec}s. Последний код ответа: ${http_code}"
      docker logs "$container_name" >&2 || true
      docker rm -f "$container_name" >/dev/null 2>&1
      TEST_FAILED=1
      return
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  docker rm -f "$container_name" >/dev/null 2>&1
  log_success "CodePilot1C /health вернул HTTP 200"
}

test_bearer_token_generation() {
  log_header "Test :: Bearer token auto-generation"
  local tag container_name output
  tag="$(resolve_image_tag)"
  container_name="edt-codepilot1c-token-test"
  
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  output=$(docker run --rm --name "$container_name" \
    --entrypoint /bin/bash "$tag" \
    -c "source /usr/local/bin/manage_codepilot_token.sh && grep 'bearerToken=' /opt/1C/1CE/components/1cedt/1cedt.ini")
  
  if echo "$output" | grep -q 'bearerToken='; then
    log_success "Bearer token generated and stored in 1cedt.ini"
  else
    log_failure "Bearer token NOT found"
    TEST_FAILED=1
  fi
}

test_plugin_jar_exists
test_ini_contains_mcp_settings
test_bearer_token_generation
test_health_endpoint

[[ -n "${CI:-}" ]] && exit "$TEST_FAILED" || exit 0
