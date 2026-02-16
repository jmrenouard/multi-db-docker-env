#!/bin/bash
# test_patroni.sh
# Functional test suite for Patroni PostgreSQL HA Cluster

set -euo pipefail

# Configuration
if [ -f .env ]; then
    export "$(grep -v '^#' .env | xargs)"
fi

DB_USER="postgres"
# Patroni/Postgres in this lab typically uses these ports via HAProxy
RW_PORT=5000
RO_PORT=5001
HAPROXY_HOST="127.0.0.1"

# Create reports directory
REPORT_DIR="./reports"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_MD="$REPORT_DIR/test_patroni_$TIMESTAMP.md"

echo "=========================================================="
echo "🚀 Patroni PostgreSQL Cluster Test Suite"
echo "=========================================================="

write_report() {
    echo -e "$1" >> "$REPORT_MD"
}

# Initialize report
cat <<EOF > "$REPORT_MD"
# Patroni Cluster Test Report
**Date:** $(date)

EOF

echo "1. 📊 Checking Cluster Status..."
STATUS_OUTPUT=$(docker exec node1 patronictl -c /etc/patroni/patroni.yml list)
echo "$STATUS_OUTPUT"
write_report "## Cluster Status\n\`\`\`\n$STATUS_OUTPUT\n\`\`\`"

# Extract Leader
LEADER_NODE=$(echo "$STATUS_OUTPUT" | grep "Leader" | awk '{print $2}')
if [ -z "$LEADER_NODE" ]; then
    echo "❌ Error: No Leader found in cluster!"
    write_report "### ❌ Status: FAIL\nNo leader detected."
    exit 1
fi
echo "✅ Leader detected: $LEADER_NODE"

echo -e "\n2. 🔌 Testing Connections via HAProxy..."
write_report "## Connectivity Tests"

# Test Read-Write Port (5000)
echo ">> Testing Read-Write port ($RW_PORT)..."
if docker run --rm --network patroni_net postgres:17-alpine psql -h haproxy -p 5000 -U $DB_USER -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Read-Write connection (port 5000) successful."
    write_report "- ✅ Read-Write (5000): SUCCESS"
else
    echo "❌ Read-Write connection (port 5000) FAILED."
    write_report "- ❌ Read-Write (5000): FAILED"
fi

# Test Read-Only Port (5001)
echo ">> Testing Read-Only port ($RO_PORT)..."
if docker run --rm --network patroni_net postgres:17-alpine psql -h haproxy -p 5001 -U $DB_USER -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Read-Only connection (port 5001) successful."
    write_report "- ✅ Read-Only (5001): SUCCESS"
else
    echo "❌ Read-Only connection (port 5001) FAILED."
    write_report "- ❌ Read-Only (5001): FAILED"
fi

echo -e "\n3. 📝 Replication Verification..."
write_report "## Replication Verification"

# Create a test table on Leader
echo ">> Creating test data on Leader ($LEADER_NODE)..."
docker exec "$LEADER_NODE" psql -U $DB_USER -c "CREATE TABLE IF NOT EXISTS replication_test (id serial PRIMARY KEY, val text, ts timestamp default now());" > /dev/null
docker exec "$LEADER_NODE" psql -U $DB_USER -c "INSERT INTO replication_test (val) VALUES ('Data from $LEADER_NODE at $(date)');" > /dev/null

# Verify on Replicas
REPLICAS=$(echo "$STATUS_OUTPUT" | grep "Replica" | awk '{print $2}')
for replica in $REPLICAS; do
    echo ">> Checking replication on $replica..."
    COUNT=$(docker exec "$replica" psql -U $DB_USER -t -c "SELECT count(*) FROM replication_test;" | xargs)
    if [ "$COUNT" -gt 0 ]; then
        echo "✅ Replication working on $replica (Count: $COUNT)"
        write_report "- ✅ Replication on $replica: SUCCESS"
    else
        echo "❌ Replication failed on $replica"
        write_report "- ❌ Replication on $replica: FAILED"
    fi
done

echo -e "\n4. ⚖️ HAProxy Load Balancing Check..."
write_report "## HAProxy Stats"
HAPROXY_STATS=$(curl -s http://localhost:7000/; echo $?)
if [ "$HAPROXY_STATS" -eq 0 ]; then
    echo "✅ HAProxy Stats dashboard available at http://localhost:7000"
    write_report "- ✅ HAProxy dashboard: UP"
else
    echo "⚠️ HAProxy Stats dashboard unavailable."
    write_report "- ⚠️ HAProxy dashboard: DOWN"
fi

echo -e "\n=========================================================="
echo "🏁 Patroni Test Suite Finished."
echo "Report generated: $REPORT_MD"
echo "=========================================================="
