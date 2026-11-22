#!/usr/bin/env bash
# Setup PostgreSQL 17 physical streaming replication (async or sync mode).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env PG_LABEL="pg-streaming" PRI="pg_stream_primary" STB="pg_stream_standby" SLOT="slot_stream_standby" SHOW_IOM=0 \
    bash "${SCRIPT_DIR}/../pg_common/setup_streaming.sh" "$@"
