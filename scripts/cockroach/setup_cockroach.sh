#!/bin/bash
# setup_cockroach.sh - Bootstrap 3-node CockroachDB v25.4 cluster (RF=3)
set -euo pipefail

DB_NAME="${CRDB_DB:-labdb}"
CRDB_INIT_LOG=$(mktemp)
trap 'rm -f "$CRDB_INIT_LOG"' EXIT

echo "=== CockroachDB Cluster Bootstrap ==="
echo "[INFO] Waiting for crdb_node1 SQL socket..."
INIT_OK=0
for _ in $(seq 1 60); do
    if docker exec crdb_node1 /cockroach/cockroach init --insecure --host=crdb_node1:26257 >"$CRDB_INIT_LOG" 2>&1; then
        echo "[OK] Cluster initialized."
        INIT_OK=1
        break
    fi
    if grep -qi "already been initialized" "$CRDB_INIT_LOG" 2>/dev/null; then
        echo "[INFO] Cluster already initialized."
        INIT_OK=1
        break
    fi
    sleep 2
done
[ "$INIT_OK" = "1" ] || { echo "[FAIL] Timeout initializing CockroachDB cluster"; exit 1; }

echo "[INFO] Waiting for 3 live nodes..."
LIVE=0
for _ in $(seq 1 60); do
    LIVE=$(docker exec crdb_node1 /cockroach/cockroach sql --insecure --host=crdb_node1:26257 \
        -e "SELECT count(*) FROM crdb_internal.gossip_nodes WHERE is_live;" --format=tsv 2>/dev/null | tail -n 1 || echo "0")
    if [ "${LIVE:-0}" = "3" ]; then
        break
    fi
    sleep 2
done
[ "${LIVE:-0}" = "3" ] || { echo "[FAIL] Timeout waiting for 3 live CockroachDB nodes (got ${LIVE:-0})"; exit 1; }

docker exec crdb_node1 /cockroach/cockroach sql --insecure --host=crdb_node1:26257 \
    -e "CREATE DATABASE IF NOT EXISTS \"${DB_NAME}\";" >/dev/null

echo "[OK] CockroachDB node status:"
docker exec crdb_node1 /cockroach/cockroach node status --insecure --host=crdb_node1:26257
