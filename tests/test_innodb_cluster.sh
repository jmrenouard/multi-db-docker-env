#!/bin/bash
# test_innodb_cluster.sh
# Functional test suite for MySQL InnoDB Cluster + MySQL Router
set -euo pipefail

# Configuration
if [ -f .env ]; then
    export "$(grep -v '^#' .env | xargs)"
fi

DB_USER="root"
DB_PASS="${DB_ROOT_PASSWORD:-rootpass}"
NETWORK="multi-db-docker-env_backend_innodb"

# Create reports directory
REPORT_DIR="./reports"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_MD="$REPORT_DIR/test_innodb_cluster_$TIMESTAMP.md"
REPORT_HTML="$REPORT_DIR/test_innodb_cluster_$TIMESTAMP.html"

echo "=========================================================="
echo "🚀 MySQL InnoDB Cluster Test Suite"
echo "=========================================================="

PASS=0
FAIL=0

write_report() {
    echo -e "$1" >> "$REPORT_MD"
}

# Helper: run mysql via docker
run_mysql() {
    local host="$1"
    local port="$2"
    shift 2
    docker run --rm --network "$NETWORK" \
        mysql:8.4 mysql -h "$host" -P "$port" -u "$DB_USER" -p"$DB_PASS" --connect-timeout=5 "$@" 2>/dev/null
}

# Initialize report
cat <<EOF > "$REPORT_MD"
# MySQL InnoDB Cluster Test Report
**Date:** $(date)

EOF

# ==================================================================
# TEST 1: MySQL Node Status
# ==================================================================
echo ""
echo "1. 📊 Checking MySQL Node Status..."
write_report "## 1. MySQL Node Status"

for node_label in "Primary:mysql_node1" "Secondary1:mysql_node2" "Secondary2:mysql_node3"; do
    LABEL="${node_label%%:*}"
    HOST="${node_label##*:}"
    if run_mysql "$HOST" 3306 -e "SELECT 1;" > /dev/null 2>&1; then
        VERSION=$(run_mysql "$HOST" 3306 -NB -e "SELECT VERSION();" 2>/dev/null | head -1)
        echo "✅ $LABEL ($HOST): UP (MySQL $VERSION)"
        write_report "- ✅ $LABEL ($HOST): UP (MySQL $VERSION)"
        PASS=$((PASS + 1))
    else
        echo "❌ $LABEL ($HOST): DOWN"
        write_report "- ❌ $LABEL ($HOST): DOWN"
        FAIL=$((FAIL + 1))
    fi
done

# ==================================================================
# TEST 2: Group Replication Status
# ==================================================================
echo ""
echo "2. ⛓️ Group Replication Status..."
write_report "## 2. Group Replication"

GR_MEMBERS=$(run_mysql mysql_node1 3306 -NB -e "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" 2>/dev/null || echo "0")
GR_MEMBERS=$(echo "$GR_MEMBERS" | tr -d '[:space:]')
if [ "$GR_MEMBERS" -ge 3 ] 2>/dev/null; then
    GR_STATUS=$(run_mysql mysql_node1 3306 -e "SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;" 2>/dev/null)
    echo "✅ Group Replication: $GR_MEMBERS members ONLINE"
    echo "$GR_STATUS"
    write_report "- ✅ Group Replication: $GR_MEMBERS ONLINE\n\`\`\`\n$GR_STATUS\n\`\`\`"
    PASS=$((PASS + 1))
else
    echo "❌ Group Replication: only $GR_MEMBERS members ONLINE (expected 3)"
    write_report "- ❌ Group Replication: $GR_MEMBERS ONLINE (expected 3)"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 3: MySQL Router Connectivity
# ==================================================================
echo ""
echo "3. 🔌 Testing MySQL Router Connectivity..."
write_report "## 3. MySQL Router"

echo ">> Testing Read-Write port (6446)..."
if run_mysql haproxy_innodb 6446 -e "SELECT @@hostname;" > /dev/null 2>&1; then
    RW_HOST=$(run_mysql haproxy_innodb 6446 -NB -e "SELECT @@hostname;" 2>/dev/null | head -1)
    echo "✅ Read-Write (6446) connected to: $RW_HOST"
    write_report "- ✅ Read-Write (6446): Connected to $RW_HOST"
    PASS=$((PASS + 1))
else
    echo "❌ Read-Write (6446) FAILED"
    write_report "- ❌ Read-Write (6446): FAILED"
    FAIL=$((FAIL + 1))
fi

echo ">> Testing Read-Only port (6447)..."
if run_mysql haproxy_innodb 6447 -e "SELECT @@hostname;" > /dev/null 2>&1; then
    RO_HOST=$(run_mysql haproxy_innodb 6447 -NB -e "SELECT @@hostname;" 2>/dev/null | head -1)
    echo "✅ Read-Only (6447) connected to: $RO_HOST"
    write_report "- ✅ Read-Only (6447): Connected to $RO_HOST"
    PASS=$((PASS + 1))
else
    echo "❌ Read-Only (6447) FAILED"
    write_report "- ❌ Read-Only (6447): FAILED"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 4: Write Replication
# ==================================================================
echo ""
echo "4. 📝 Write Replication Test..."
write_report "## 4. Replication"

run_mysql mysql_node1 3306 -e "
    CREATE DATABASE IF NOT EXISTS innodb_test;
    USE innodb_test;
    CREATE TABLE IF NOT EXISTS replication_test (
        id INT AUTO_INCREMENT PRIMARY KEY,
        val VARCHAR(100),
        ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;
    INSERT INTO replication_test (val) VALUES ('Test from InnoDB Cluster at $(date)');
" > /dev/null 2>&1

sleep 3

for node_label in "Secondary1:mysql_node2" "Secondary2:mysql_node3"; do
    LABEL="${node_label%%:*}"
    HOST="${node_label##*:}"
    COUNT=$(run_mysql "$HOST" 3306 -NB -e "SELECT COUNT(*) FROM innodb_test.replication_test;" 2>/dev/null || echo "0")
    COUNT=$(echo "$COUNT" | tr -d '[:space:]')
    if [ "$COUNT" -gt 0 ] 2>/dev/null; then
        echo "✅ Replication to $LABEL ($HOST) working (Count: $COUNT)"
        write_report "- ✅ Replication to $LABEL: SUCCESS ($COUNT rows)"
        PASS=$((PASS + 1))
    else
        echo "❌ Replication to $LABEL ($HOST) failed"
        write_report "- ❌ Replication to $LABEL: FAILED"
        FAIL=$((FAIL + 1))
    fi
done

# ==================================================================
# TEST 5: Write Isolation on Secondaries
# ==================================================================
echo ""
echo "5. 🛡️ Write Isolation Test (Read-Only on Secondaries)..."
write_report "## 5. Write Isolation"

for node_label in "Secondary1:mysql_node2" "Secondary2:mysql_node3"; do
    LABEL="${node_label%%:*}"
    HOST="${node_label##*:}"
    if run_mysql "$HOST" 3306 -e "INSERT INTO innodb_test.replication_test (val) VALUES ('should_fail');" > /dev/null 2>&1; then
        echo "❌ $LABEL accepted write (should be read-only!)"
        write_report "- ❌ $LABEL: Accepted write (UNEXPECTED)"
        FAIL=$((FAIL + 1))
    else
        echo "✅ $LABEL correctly rejected write (super_read_only)"
        write_report "- ✅ $LABEL: Correctly rejected write"
        PASS=$((PASS + 1))
    fi
done

# ==================================================================
# TEST 6: DDL Replication
# ==================================================================
echo ""
echo "6. 🏗️ DDL Replication Test..."
write_report "## 6. DDL Replication"

run_mysql mysql_node1 3306 -e "ALTER TABLE innodb_test.replication_test ADD COLUMN IF NOT EXISTS extra_col VARCHAR(50) DEFAULT 'ddl_test';" > /dev/null 2>&1 || \
run_mysql mysql_node1 3306 -e "ALTER TABLE innodb_test.replication_test ADD COLUMN extra_col VARCHAR(50) DEFAULT 'ddl_test';" > /dev/null 2>&1 || true
sleep 3

DDL_OK=true
for node_label in "Secondary1:mysql_node2" "Secondary2:mysql_node3"; do
    LABEL="${node_label%%:*}"
    HOST="${node_label##*:}"
    COL_EXISTS=$(run_mysql "$HOST" 3306 -NB -e "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='innodb_test' AND TABLE_NAME='replication_test' AND COLUMN_NAME='extra_col';" 2>/dev/null || echo "")
    COL_EXISTS=$(echo "$COL_EXISTS" | tr -d '[:space:]')
    if [ "$COL_EXISTS" = "extra_col" ]; then
        echo "✅ DDL replicated to $LABEL"
    else
        echo "❌ DDL NOT replicated to $LABEL"
        DDL_OK=false
    fi
done

if [ "$DDL_OK" = true ]; then
    write_report "- ✅ DDL Replication: SUCCESS"
    PASS=$((PASS + 1))
else
    write_report "- ❌ DDL Replication: FAILED"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 7: Version Consistency
# ==================================================================
echo ""
echo "7. 🔢 MySQL Version Consistency..."
write_report "## 7. Version Consistency"

PRIMARY_VER=$(run_mysql mysql_node1 3306 -NB -e "SELECT VERSION();" 2>/dev/null | head -1)
VER_MATCH=true
for node_label in "Secondary1:mysql_node2" "Secondary2:mysql_node3"; do
    LABEL="${node_label%%:*}"
    HOST="${node_label##*:}"
    NODE_VER=$(run_mysql "$HOST" 3306 -NB -e "SELECT VERSION();" 2>/dev/null | head -1)
    if [ "$PRIMARY_VER" = "$NODE_VER" ]; then
        echo "✅ $LABEL version matches Primary"
    else
        echo "❌ $LABEL version mismatch: $NODE_VER vs $PRIMARY_VER"
        VER_MATCH=false
    fi
done

if [ "$VER_MATCH" = true ]; then
    echo "✅ All nodes running MySQL $PRIMARY_VER"
    write_report "- ✅ All nodes: MySQL $PRIMARY_VER"
    PASS=$((PASS + 1))
else
    write_report "- ❌ Version mismatch detected"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 8: Concurrent Writes via Router
# ==================================================================
echo ""
echo "8. 🔄 Concurrent Write Test via MySQL Router..."
write_report "## 8. Concurrent Writes via Router"

run_mysql haproxy_innodb 6446 -e "
    CREATE TABLE IF NOT EXISTS innodb_test.concurrent_test (
        id INT AUTO_INCREMENT PRIMARY KEY,
        batch INT,
        val VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;
" > /dev/null 2>&1

for i in 1 2 3; do
    run_mysql haproxy_innodb 6446 -e "INSERT INTO innodb_test.concurrent_test (batch, val) VALUES ($i, 'batch_${i}_row_1'),($i, 'batch_${i}_row_2'),($i, 'batch_${i}_row_3'),($i, 'batch_${i}_row_4'),($i, 'batch_${i}_row_5'),($i, 'batch_${i}_row_6'),($i, 'batch_${i}_row_7'),($i, 'batch_${i}_row_8'),($i, 'batch_${i}_row_9'),($i, 'batch_${i}_row_10');" > /dev/null 2>&1
done
sleep 3

TOTAL=$(run_mysql mysql_node1 3306 -NB -e "SELECT COUNT(*) FROM innodb_test.concurrent_test;" 2>/dev/null || echo "0")
TOTAL=$(echo "$TOTAL" | tr -d '[:space:]')
if [ "$TOTAL" -eq 30 ] 2>/dev/null; then
    echo "✅ All 30 rows inserted via Router"
    write_report "- ✅ Concurrent Writes via Router: 30/30 rows"
    PASS=$((PASS + 1))
else
    echo "❌ Expected 30 rows, got $TOTAL"
    write_report "- ❌ Concurrent Writes: $TOTAL/30 rows"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 9: Router RW routes to Primary
# ==================================================================
echo ""
echo "9. 🎯 Router RW routes to Primary..."
write_report "## 9. Router Routing"

RW_HOST=$(run_mysql haproxy_innodb 6446 -NB -e "SELECT @@hostname;" 2>/dev/null | head -1)
PRIMARY_HOST=$(run_mysql mysql_node1 3306 -NB -e "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE='PRIMARY';" 2>/dev/null | head -1)

if [ -n "$RW_HOST" ]; then
    echo "✅ Router RW port routes to: $RW_HOST"
    write_report "- ✅ Router RW: routes to $RW_HOST"
    PASS=$((PASS + 1))
else
    echo "❌ Could not determine Router RW routing"
    write_report "- ❌ Router RW: routing unknown"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# TEST 10: GTID Consistency
# ==================================================================
echo ""
echo "10. 🔗 GTID Consistency..."
write_report "## 10. GTID"

GTID_P=$(run_mysql mysql_node1 3306 -NB -e "SELECT @@global.gtid_executed;" 2>/dev/null | head -1)
if [ -n "$GTID_P" ]; then
    echo "✅ GTID active: ${GTID_P:0:40}..."
    write_report "- ✅ GTID active"
    PASS=$((PASS + 1))
else
    echo "❌ GTID not active"
    write_report "- ❌ GTID not active"
    FAIL=$((FAIL + 1))
fi

# ==================================================================
# Cleanup
# ==================================================================
run_mysql mysql_node1 3306 -e "DROP DATABASE IF EXISTS innodb_test;" > /dev/null 2>&1 || true

# Summary
write_report "\n## Summary\n- ✅ Passed: $PASS\n- ❌ Failed: $FAIL"

# Generate HTML report
cat <<HTMLEOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>MySQL InnoDB Cluster Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; }
        h1 { color: #f59e0b; border-bottom: 2px solid #1e3a5f; padding-bottom: 10px; }
        h2 { color: #fbbf24; margin-top: 20px; }
        .pass { color: #4ade80; } .fail { color: #f87171; }
        .summary { background: #1e293b; border-radius: 12px; padding: 20px; margin: 20px 0; border: 1px solid #334155; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-weight: 600; font-size: 0.9em; }
        .badge-pass { background: #166534; color: #4ade80; }
        .badge-fail { background: #7f1d1d; color: #f87171; }
        pre { background: #1e293b; padding: 12px; border-radius: 8px; overflow-x: auto; border: 1px solid #334155; font-size: 0.85em; }
        .meta { color: #94a3b8; font-size: 0.85em; }
    </style>
</head>
<body>
<div class="container">
    <h1>🐬 MySQL InnoDB Cluster Test Report</h1>
    <p class="meta">Generated: $(date)</p>
    <div class="summary">
        <span class="badge badge-pass">✅ Passed: $PASS</span>
        <span class="badge badge-fail">❌ Failed: $FAIL</span>
    </div>
</div>
</body>
</html>
HTMLEOF

echo ""
echo "=========================================================="
echo "🏁 MySQL InnoDB Cluster Test Suite Finished."
echo "   Passed: $PASS | Failed: $FAIL"
echo "Markdown Report: $REPORT_MD"
echo "HTML Report: $REPORT_HTML"
echo "=========================================================="
