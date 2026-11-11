#!/bin/bash
set -eo pipefail

# shellcheck source=cs-common/build-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cs-common/build-lib.sh"

CS_IMAGE=cs-server
CS_DOCKERFILE=src/cs-server/Dockerfile
CS_TEST=tests/test-cs-server.sh
CS_NEEDS_BASE=true

cs_build
