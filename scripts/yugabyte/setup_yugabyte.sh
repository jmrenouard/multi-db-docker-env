#!/bin/bash
# setup_yugabyte.sh - Verify 3-node YugabyteDB RF=3 cluster and create labdb
set -euo pipefail

DB_NAME="${YB_DB:-labdb}"
NODES=("yb_node1:yb-node1" "yb_node2:yb-node2" "yb_node3:yb-node3")

echo "=== YugabyteDB Cluster Bootstrap ==="
for pair in "${NODES[@]}"; do
    cname="${pair%%:*}"
    hname="${pair##*:}"
    echo "[INFO] Waiting for YSQL on $cname ($hname)..."
    for _ in $(seq 1 90); do
        if docker exec "$cname" /home/yugabyte/bin/ysqlsh -h "$hname" -p 5433 -U yugabyte -c "SELECT 1;" >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
    docker exec "$cname" /home/yugabyte/bin/ysqlsh -h "$hname" -p 5433 -U yugabyte -c "SELECT 1;" >/dev/null 2>&1
done

echo "[INFO] Waiting for 3 TServers in RF=3 quorum..."
for _ in $(seq 1 60); do
    TS_CNT=$(docker exec yb_node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte -tAc "SELECT count(*) FROM yb_servers();" 2>/dev/null || echo "0")
    [ "${TS_CNT:-0}" = "3" ] && break
    sleep 2
done

docker exec yb_node1 /home/yugabyte/bin/yugabyted configure data_placement --fault_tolerance=zone --base_dir=/home/yugabyte/var >/dev/null 2>&1 || true

EXISTS=$(docker exec yb_node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';")
if [ "$EXISTS" != "1" ]; then
    docker exec yb_node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte -c "CREATE DATABASE \"${DB_NAME}\";" >/dev/null
fi

echo "[OK] YugabyteDB cluster status:"
docker exec yb_node1 /home/yugabyte/bin/yugabyted status --base_dir=/home/yugabyte/var
docker exec yb_node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte -d "$DB_NAME" -c "SELECT host, port, cloud, region, zone FROM yb_servers() ORDER BY host;"
