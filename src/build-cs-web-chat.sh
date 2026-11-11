#!/bin/bash
set -eo pipefail

# shellcheck source=cs-common/build-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cs-common/build-lib.sh"

CS_IMAGE=cs-web-chat
CS_DOCKERFILE=src/cs-web-chat/Dockerfile
CS_TEST=tests/test-cs-web-chat.sh
CS_NEEDS_BASE=true

cs_build
