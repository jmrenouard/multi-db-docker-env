#!/usr/bin/env bash
# Setup bidirectional logical replication on two PostgreSQL 18 nodes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env N1="pg18_birep_node1" N2="pg18_birep_node2" PUB_NAME="pub_pg18_birep" \
    bash "${SCRIPT_DIR}/../pg_common/setup_birep.sh" "$@"
