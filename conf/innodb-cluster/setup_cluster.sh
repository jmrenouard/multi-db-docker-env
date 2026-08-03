#!/bin/bash
# setup_cluster.sh
# Creates a MySQL InnoDB Cluster using Group Replication
# Installs GR plugin via SQL, resets errant GTIDs, configures replication
set -euo pipefail

DB_PASS="${DB_ROOT_PASSWORD:-rootpass}"
NODES=("mysql_node1" "mysql_node2" "mysql_node3")

echo "=========================================================="
echo "⚙️  MySQL InnoDB Cluster Setup"
echo "=========================================================="

# 1. Wait for all nodes to be ready
echo ""
echo "1. ⏳ Waiting for all MySQL nodes to be ready (max 120s)..."
for node in "${NODES[@]}"; do
    TIMEOUT=120
    ELAPSED=0
    while ! docker exec -e MYSQL_PWD="$DB_PASS" "$node" mysql -uroot -e "SELECT 1" &>/dev/null; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo "❌ Timeout waiting for $node"
            exit 1
        fi
    done
    echo "   ✅ $node is ready."
done

# 2. Install Group Replication plugin on all nodes
echo ""
echo "2. ⛓️  Installing Group Replication plugin..."
for node in "${NODES[@]}"; do
    docker exec -e MYSQL_PWD="$DB_PASS" "$node" mysql -uroot -e "
        INSTALL PLUGIN group_replication SONAME 'group_replication.so';
    " 2>/dev/null || true
    echo "   ✅ GR plugin installed on $node."
done

# 3. Reset errant GTIDs on all nodes (each node has independent GTIDs from init)
echo ""
echo "3. 🔄 Resetting GTID state on all nodes..."
for node in "${NODES[@]}"; do
    docker exec -e MYSQL_PWD="$DB_PASS" "$node" mysql -uroot -e "
        RESET MASTER;
    " 2>/dev/null || true
    echo "   ✅ GTID reset on $node."
done

# 4. Create replication user on all nodes (after RESET MASTER)
echo ""
echo "4. 👤 Creating replication user on all nodes..."
for node in "${NODES[@]}"; do
    docker exec -e MYSQL_PWD="$DB_PASS" "$node" mysql -uroot -e "
        SET SQL_LOG_BIN=0;
        CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replpass';
        GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
        GRANT CONNECTION_ADMIN ON *.* TO 'repl_user'@'%';
        GRANT BACKUP_ADMIN ON *.* TO 'repl_user'@'%';
        FLUSH PRIVILEGES;
        SET SQL_LOG_BIN=1;
    " 2>/dev/null
    echo "   ✅ Replication user configured on $node."
done

# 5. Configure and start Group Replication on primary (Node 1)
echo ""
echo "5. ⛓️  Starting Group Replication on primary (mysql_node1)..."
docker exec -e MYSQL_PWD="$DB_PASS" mysql_node1 mysql -uroot -e "
    CHANGE REPLICATION SOURCE TO SOURCE_USER='repl_user', SOURCE_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
    SET GLOBAL group_replication_bootstrap_group=ON;
    START GROUP_REPLICATION;
    SET GLOBAL group_replication_bootstrap_group=OFF;
" 2>/dev/null
echo "   ✅ Primary node bootstrapped."
sleep 5

# 6. Join secondary nodes
echo ""
echo "6. ⛓️  Joining secondary nodes..."
for node in "mysql_node2" "mysql_node3"; do
    echo "   >> Joining $node..."
    docker exec -e MYSQL_PWD="$DB_PASS" "$node" mysql -uroot -e "
        CHANGE REPLICATION SOURCE TO SOURCE_USER='repl_user', SOURCE_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
        START GROUP_REPLICATION;
    " 2>/dev/null
    echo "   ✅ $node join initiated."
    sleep 8
done

# 7. Verify Group Replication status (Wait for ONLINE state, max 60s)
echo ""
echo "7. 📊 Waiting for Group Replication nodes to reach ONLINE state..."
EXPECTED_NODES=3
MAX_WAIT=60
START_TIME=$(date +%s)
ONLINE_COUNT=0

while [ $(($(date +%s) - START_TIME)) -lt $MAX_WAIT ]; do
    ONLINE_COUNT=$(docker exec -e MYSQL_PWD="$DB_PASS" mysql_node1 mysql -uroot -NB -e "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" 2>/dev/null || echo "0")
    ONLINE_COUNT=$(echo "$ONLINE_COUNT" | tr -d '[:space:]')
    if [ "$ONLINE_COUNT" -ge "$EXPECTED_NODES" ] 2>/dev/null; then
        echo "   ✅ All $EXPECTED_NODES nodes reached ONLINE state."
        break
    fi
    sleep 2
done

if [ "$ONLINE_COUNT" -lt "$EXPECTED_NODES" ]; then
    echo "❌ ERROR: Timeout waiting for $EXPECTED_NODES Group Replication nodes to reach ONLINE state (current: $ONLINE_COUNT)." >&2
    exit 1
fi

docker exec -e MYSQL_PWD="$DB_PASS" mysql_node1 mysql -uroot -e "
    SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;
" 2>/dev/null

echo ""
echo "=========================================================="
echo "🏁 InnoDB Cluster Setup Finished"
echo "=========================================================="
