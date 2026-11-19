#!/bin/bash
# setup_citus.sh - Bootstrap 3-node Citus cluster (1 coordinator + 2 workers)
set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

PG_PASS="${PG_LAB_PASSWORD:-${DB_ROOT_PASSWORD:-pg_poc_ephemeral}}"
DB_NAME="${CITUS_DB:-labdb}"
NODES=("citus_coord" "citus_worker1" "citus_worker2")

echo "=== Citus Cluster Bootstrap ==="

for node in "${NODES[@]}"; do
    echo "[INFO] Waiting for $node..."
    for _ in $(seq 1 60); do
        if docker exec -e PGPASSWORD="$PG_PASS" "$node" \
            psql -h "$node" -p 5432 -U postgres -d postgres -tAc "SELECT 1;" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    docker exec -e PGPASSWORD="$PG_PASS" "$node" \
        psql -h "$node" -p 5432 -U postgres -d postgres -tAc "SELECT 1;" >/dev/null 2>&1

    # Configure internal .pgpass for inter-node coordinator-worker queries
    docker exec -u postgres -e PG_PASS_VAL="$PG_PASS" "$node" bash -c '
        umask 077
        printf "*:*:*:postgres:%s\n" "$PG_PASS_VAL" > "$HOME/.pgpass"
    '
done

echo "[INFO] Initializing database $DB_NAME on all nodes..."
for node in "${NODES[@]}"; do
    EXISTS=$(docker exec -e PGPASSWORD="$PG_PASS" "$node" \
        psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';")
    if [ "$EXISTS" != "1" ]; then
        docker exec -e PGPASSWORD="$PG_PASS" "$node" \
            psql -U postgres -d postgres -c "CREATE DATABASE \"${DB_NAME}\";" >/dev/null
    fi
    docker exec -e PGPASSWORD="$PG_PASS" "$node" \
        psql -U postgres -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS citus;" >/dev/null
done

echo "[INFO] Registering coordinator and workers in $DB_NAME..."
docker exec -e PGPASSWORD="$PG_PASS" citus_coord psql -U postgres -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "
    SELECT citus_set_coordinator_host('citus_coord', 5432);
    SELECT citus_add_node('citus_worker1', 5432)
    WHERE NOT EXISTS (SELECT 1 FROM pg_dist_node WHERE nodename = 'citus_worker1' AND nodeport = 5432);
    SELECT citus_add_node('citus_worker2', 5432)
    WHERE NOT EXISTS (SELECT 1 FROM pg_dist_node WHERE nodename = 'citus_worker2' AND nodeport = 5432);
" >/dev/null

echo "[OK] Citus cluster topology:"
docker exec -e PGPASSWORD="$PG_PASS" citus_coord psql -U postgres -d "$DB_NAME" \
    -c "SELECT nodeid, groupid, nodename, nodeport, isactive, shouldhaveshards FROM pg_dist_node ORDER BY nodeid;"
