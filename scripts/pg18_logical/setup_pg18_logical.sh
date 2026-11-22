#!/usr/bin/env bash
# Setup PostgreSQL 18 native uni-directional logical replication (pub -> sub).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env PUB="pg18_logical_pub" SUB="pg18_logical_sub" PUB_NAME="pub_pg18_logical" SUB_NAME="sub_pg18_logical" SHOW_SUBSTREAM=1 \
    bash "${SCRIPT_DIR}/../pg_common/setup_logical.sh" "$@"
