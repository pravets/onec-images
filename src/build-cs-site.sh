#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=cs-common/build-lib.sh
source "${SCRIPT_DIR}/cs-common/build-lib.sh"

CS_IMAGE=cs-site
CS_DOCKERFILE=src/cs-site/Dockerfile
CS_TEST=tests/test-cs-site.sh
CS_NEEDS_BASE=true

cs_build
