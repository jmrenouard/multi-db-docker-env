#!/usr/bin/env bash
# Setup PostgreSQL 17 native uni-directional logical replication (pub -> sub).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env PUB="pg_logical_pub" SUB="pg_logical_sub" PUB_NAME="pub_logical" SUB_NAME="sub_logical" SHOW_SUBSTREAM=0 \
    bash "${SCRIPT_DIR}/../pg_common/setup_logical.sh" "$@"
