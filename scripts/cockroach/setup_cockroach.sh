#!/bin/bash
# setup_cockroach.sh - Bootstrap 3-node CockroachDB v24.3.0 cluster (RF=3)
set -euo pipefail

DB_NAME="${CRDB_DB:-labdb}"

echo "=== CockroachDB Cluster Bootstrap ==="
echo "[INFO] Waiting for crdb_node1 SQL socket..."
for _ in $(seq 1 60); do
    if docker exec crdb_node1 /cockroach/cockroach init --insecure --host=crdb_node1:26257 >/tmp/crdb_init.out 2>&1; then
        echo "[OK] Cluster initialized."
        break
    fi
    if grep -qi "already been initialized" /tmp/crdb_init.out 2>/dev/null; then
        echo "[INFO] Cluster already initialized."
        break
    fi
    sleep 2
done
rm -f /tmp/crdb_init.out

echo "[INFO] Waiting for 3 live nodes..."
for _ in $(seq 1 60); do
    LIVE=$(docker exec crdb_node1 /cockroach/cockroach sql --insecure --host=crdb_node1:26257 \
        -e "SELECT count(*) FROM crdb_internal.gossip_nodes WHERE is_live;" --format=tsv 2>/dev/null | tail -n 1 || echo "0")
    if [ "${LIVE:-0}" = "3" ]; then
        break
    fi
    sleep 2
done

docker exec crdb_node1 /cockroach/cockroach sql --insecure --host=crdb_node1:26257 \
    -e "CREATE DATABASE IF NOT EXISTS \"${DB_NAME}\";" >/dev/null

echo "[OK] CockroachDB node status:"
docker exec crdb_node1 /cockroach/cockroach node status --insecure --host=crdb_node1:26257
