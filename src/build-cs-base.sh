#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=cs-common/build-lib.sh
source "${SCRIPT_DIR}/cs-common/build-lib.sh"

CS_IMAGE=cs-base
CS_DOCKERFILE=src/cs-base/Dockerfile
CS_TEST=tests/test-cs-base.sh
CS_NEEDS_BASE=false

cs_build
