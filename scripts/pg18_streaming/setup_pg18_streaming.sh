#!/usr/bin/env bash
# Setup PostgreSQL 18 physical streaming replication (async or sync mode).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env PG_LABEL="pg18-streaming" PRI="pg18_stream_primary" STB="pg18_stream_standby" SLOT="slot_pg18_standby" SHOW_IOM=1 \
    bash "${SCRIPT_DIR}/../pg_common/setup_streaming.sh" "$@"
