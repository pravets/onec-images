#!/bin/bash
set -e

if [ -z ${CI} ]; then
        echo "The script is not running in CI"
        source .env
else
        echo "The script is running in CI";
fi

source "./tools/assert.sh"

test_executor_version() {
  log_header "Test :: executor version"

  local expected actual
  expected=$(echo $EXECUTOR_VERSION | sed 's/\(.*\)\./\1-/')
  actual=$(docker run --rm $DOCKER_REGISTRY_URL/executor:$EXECUTOR_VERSION --version)

  if assert_contain "$actual" "$expected"; then
    log_success "executor version test passed"
  else
    log_failure "executor version test failed"
  fi
}

# test calls
test_executor_version
