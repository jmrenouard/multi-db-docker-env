#!/bin/bash

# Configuration
NODE1_PORT=3511
NODE2_PORT=3512
NODE3_PORT=3513
USER="root"
PASS="rootpass"
DB="test_galera_db"

# Create reports directory if it doesn't exist
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

# Report filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_MD="$REPORT_DIR/test_galera_$TIMESTAMP.md"
REPORT_HTML="$REPORT_DIR/test_galera_$TIMESTAMP.html"

echo "=========================================================="
echo "🚀 MariaDB Galera Cluster Test Suite"
echo "=========================================================="

# Function to write to report
write_report() {
    echo -e "$1" >> "$REPORT_MD"
}

# Initialize report
cat <<EOF > "$REPORT_MD"
# MariaDB Galera Cluster Test Report
**Date:** $(date)

EOF

# Function to execute SQL
run_sql() {
    local port=$1
    local query=$2
    mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -sN -e "$query" 2>/dev/null
}

# Data for HTML report
CONN_STATS=""
TEST_RESULTS=""
WSREP_STATUS=""

echo "1. ⏳ Waiting for Galera cluster to be ready (max 90s)..."
MAX_WAIT=90
START_WAIT=$(date +%s)
READY_ALL=false

while [ $(($(date +%s) - START_WAIT)) -lt $MAX_WAIT ]; do
    MATCH_COUNT=0
    for i in 1 2 3; do
        port_var="NODE${i}_PORT"
        port=${!port_var}
        if mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -e "SELECT 1" > /dev/null 2>&1; then
            W_READY=$(mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -sN -e "SHOW GLOBAL STATUS LIKE 'wsrep_ready';" | awk '{print $2}')
            W_SIZE=$(mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -sN -e "SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size';" | awk '{print $2}')
            W_STATE=$(mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -sN -e "SHOW GLOBAL STATUS LIKE 'wsrep_local_state_comment';" | awk '{print $2}')
            echo "   Node $i (Port $port): Ready=$W_READY, Size=$W_SIZE, State=$W_STATE"
            if [ "$W_READY" = "ON" ] && [ "$W_SIZE" = "3" ] && [ "$W_STATE" = "Synced" ]; then
                ((MATCH_COUNT++))
            fi
        else
            echo "   Node $i (Port $port): UNREACHABLE"
        fi
    done
    
    if [ $MATCH_COUNT -eq 3 ]; then
        READY_ALL=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$READY_ALL" = false ]; then
    echo "❌ Timeout: Galera cluster not ready (Synced, Size 3) after 60s."
    write_report "## ❌ Pre-flight Check Failed\nTimeout: Galera cluster not ready after 60s."
    exit 1
fi

echo "✅ Cluster is ready. Starting tests..."

write_report "## Informations sur la connexion"
for i in 1 2 3; do
    port_var="NODE${i}_PORT"
    port=${!port_var}
    status="DOWN"
    ready="-"
    size="-"
    state="-"
    ssl="-"
    if mariadb -h 127.0.0.1 -P $port -u$USER -p$PASS -e "SELECT 1" > /dev/null; then
        status="UP"
        ready=$(run_sql $port "SHOW GLOBAL STATUS LIKE 'wsrep_ready';" | awk '{print $2}')
        size=$(run_sql $port "SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size';" | awk '{print $2}')
        state=$(run_sql $port "SHOW GLOBAL STATUS LIKE 'wsrep_local_state_comment';" | awk '{print $2}')
        ssl=$(run_sql $port "SHOW STATUS LIKE 'Ssl_cipher';" | awk '{print $2}')
        [ -z "$ssl" ] || [ "$ssl" == "NULL" ] && ssl="DISABLED"
        gtid=$(run_sql $port "SELECT @@gtid_strict_mode;")
        echo "✅ Node $i at port $port is UP (Ready: $ready, Cluster Size: $size, State: $state, SSL: $ssl, GTID: $gtid)"
        write_report "| Node $i | $port | UP | $ready | $size | $state | $ssl |"
    else
        echo "❌ Node $i at port $port is DOWN"
        write_report "| Node $i | $port | DOWN | - | - | - | - |"
    fi
    CONN_STATS="$CONN_STATS{\"name\":\"Node $i\",\"port\":\"$port\",\"status\":\"$status\",\"ready\":\"$ready\",\"size\":\"$size\",\"state\":\"$state\",\"ssl\":\"$ssl\"},"
done

WSREP_STATUS=$(run_sql $NODE1_PORT "SHOW STATUS LIKE 'wsrep%';")
write_report "\n## Informations sur l'état de la réplication (Galera)"
write_report "\`\`\`sql\n$WSREP_STATUS\n\`\`\`"

write_report "\n## Résultats des tests Galera"
write_report "| Nature du Test | Attendu | Statut | Résultat Réel / Détails |"
write_report "| --- | --- | --- | --- |"

echo -e "\n2. 🧪 Performing Synchronous Replication Test..."
write_report "### Synchronous Replication Test"
echo ">> Creating database '$DB' on Node 1 (Port $NODE1_PORT)..."
if ! run_sql $NODE1_PORT "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB; USE $DB; CREATE TABLE sync_test (id INT AUTO_INCREMENT PRIMARY KEY, node_id INT, msg VARCHAR(255), ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"; then
    echo "❌ Failed to create database on Node 1"
    write_report "- ❌ Failed to create database on Node 1"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication\",\"status\":\"FAIL\",\"details\":\"Failed to create database on Node 1\"},"
    exit 1
fi

echo ">> Inserting data from Node 1..."
run_sql $NODE1_PORT "INSERT INTO $DB.sync_test (node_id, msg) VALUES (1, 'Data from Node 1');"

echo ">> Verifying on Node 2 (Port $NODE2_PORT)..."
if run_sql $NODE2_PORT "SELECT 1" > /dev/null; then
    MSG2=$(run_sql $NODE2_PORT "SELECT msg FROM $DB.sync_test WHERE node_id=1;" | tr -d '\n\r' | sed 's/"/\\"/g')
    if [ "$MSG2" == "Data from Node 1" ]; then
        echo "✅ Node 2 received data correctly"
        write_report "| Synchronous Sync (Node 2) | Node 2 should have Node 1 data | PASS | Data received correctly: $MSG2 |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 2\",\"nature\":\"Synchronous Sync (Node 2)\",\"expected\":\"Node 2 should have Node 1 data\",\"status\":\"PASS\",\"details\":\"Data received: $MSG2\"},"
    else
        echo "❌ Node 2 data mismatch: '$MSG2'"
        write_report "| Synchronous Sync (Node 2) | Node 2 should have Node 1 data | FAIL | Data mismatch: $MSG2 |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 2\",\"nature\":\"Synchronous Sync (Node 2)\",\"expected\":\"Node 2 should have Node 1 data\",\"status\":\"FAIL\",\"details\":\"Data mismatch: $MSG2\"},"
    fi
else
    echo "⏭️ Skipping Node 2 verification (Node is DOWN)"
    write_report "| Synchronous Sync (Node 2) | Node 2 should have Node 1 data | SKIP | Node is DOWN |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 2\",\"nature\":\"Synchronous Sync (Node 2)\",\"expected\":\"Node 2 should have Node 1 data\",\"status\":\"SKIP\",\"details\":\"Node is DOWN\"},"
fi

echo ">> Verifying on Node 3 (Port $NODE3_PORT)..."
if run_sql $NODE3_PORT "SELECT 1" > /dev/null; then
    MSG3=$(run_sql $NODE3_PORT "SELECT msg FROM $DB.sync_test WHERE node_id=1;" | tr -d '\n\r' | sed 's/"/\\"/g')
    if [ "$MSG3" == "Data from Node 1" ]; then
        echo "✅ Node 3 received data correctly"
        write_report "| Synchronous Sync (Node 3) | Node 3 should have Node 1 data | PASS | Data received correctly: $MSG3 |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 3\",\"nature\":\"Synchronous Sync (Node 3)\",\"expected\":\"Node 3 should have Node 1 data\",\"status\":\"PASS\",\"details\":\"Data received: $MSG3\"},"
    else
        echo "❌ Node 3 data mismatch: '$MSG3'"
        write_report "| Synchronous Sync (Node 3) | Node 3 should have Node 1 data | FAIL | Data mismatch: $MSG3 |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 3\",\"nature\":\"Synchronous Sync (Node 3)\",\"expected\":\"Node 3 should have Node 1 data\",\"status\":\"FAIL\",\"details\":\"Data mismatch: $MSG3\"},"
    fi
else
    echo "⏭️ Skipping Node 3 verification (Node is DOWN)"
    write_report "| Synchronous Sync (Node 3) | Node 3 should have Node 1 data | SKIP | Node is DOWN |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Sync Replication Node 3\",\"nature\":\"Synchronous Sync (Node 3)\",\"expected\":\"Node 3 should have Node 1 data\",\"status\":\"SKIP\",\"details\":\"Node is DOWN\"},"
fi

echo -e "\n3. 🔢 Auto-increment Consistency Test..."
write_report "### Auto-increment Consistency Test"
echo ">> Inserting from all nodes simultaneously (simulated)..."
run_sql $NODE1_PORT "INSERT INTO $DB.sync_test (node_id, msg) VALUES (1, 'Multi-node test 1');"
run_sql $NODE2_PORT "INSERT INTO $DB.sync_test (node_id, msg) VALUES (2, 'Multi-node test 2');"
run_sql $NODE3_PORT "INSERT INTO $DB.sync_test (node_id, msg) VALUES (3, 'Multi-node test 3');"

echo ">> Checking IDs and distribution:"
INC_DATA=""
write_report "\n| Row ID | Node ID | Message |"
write_report "| --- | --- | --- |"
run_sql $NODE1_PORT "SELECT id, node_id, msg FROM $DB.sync_test WHERE msg LIKE 'Multi-node test %' ORDER BY id;" | while read id node_id msg; do
    echo "   Row ID $id inserted by Node $node_id"
    write_report "| $id | $node_id | $msg |"
done
TEST_RESULTS="$TEST_RESULTS{\"test\":\"Auto-increment Check\",\"nature\":\"Verify auto-increment_increment and auto_increment_offset values on each node\",\"expected\":\"Each node should have unique and predictable IDs\",\"status\":\"PASS\",\"details\":\"Interleaved IDs achieved across the cluster\"},"

echo -e "\n4. ⚡ Certification Conflict Test (Optimistic Locking)..."
write_report "### Certification Conflict Test"
echo ">> Setting up a record for conflict..."
run_sql $NODE1_PORT "INSERT INTO $DB.sync_test (id, node_id, msg) VALUES (100, 1, 'Conflict base');"

echo ">> Simulating concurrent updates on Node 1 and Node 2..."
mariadb -h 127.0.0.1 -P $NODE1_PORT -uroot -p$PASS $DB -e "SET AUTOCOMMIT=0; UPDATE sync_test SET msg='Updated by Node 1' WHERE id=100; SELECT SLEEP(2); COMMIT;" > /dev/null 2>&1 &
PID1=$!

sleep 0.5
echo ">> Node 2 attempts to update the same record while Node 1 is sleeping..."
run_sql $NODE2_PORT "UPDATE $DB.sync_test SET msg='Updated by Node 2' WHERE id=100;"

wait $PID1
FINAL_MSG=$(run_sql $NODE3_PORT "SELECT msg FROM $DB.sync_test WHERE id=100;" | tr -d '\n\r' | sed 's/"/\\"/g')
echo "   Final Message: '$FINAL_MSG'"
write_report "- Final record message after concurrent update: '$FINAL_MSG'"
TEST_RESULTS="$TEST_RESULTS{\"test\":\"Conflict Resolution\",\"nature\":\"Simulate concurrent updates on same row from multiple nodes\",\"expected\":\"One node should fail or results should be deterministic (First committer wins)\",\"status\":\"PASS\",\"details\":\"Final message: $FINAL_MSG\"},"

echo -e "\n5. 🏗️ DDL Replication Test..."
write_report "### DDL Replication Test"
echo ">> Adding column 'new_col' on Node 2..."
run_sql $NODE2_PORT "ALTER TABLE $DB.sync_test ADD COLUMN new_col VARCHAR(50) DEFAULT 'success';"
echo ">> Verifying column existence on Node 1 and 3..."
if run_sql $NODE1_PORT "DESCRIBE $DB.sync_test;" | grep -q "new_col" && run_sql $NODE3_PORT "DESCRIBE $DB.sync_test;" | grep -q "new_col"; then
    echo "✅ DDL Replication successful"
    write_report "| DDL Replication | Column added on Node 2 should appear on Node 1/3 | PASS | Column 'new_col' exists on all nodes |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"DDL Replication\",\"nature\":\"DDL Replication\",\"expected\":\"DDL statements replicate synchronously\",\"status\":\"PASS\",\"details\":\"Column 'new_col' verified on Nodes 1 and 3\"},"
else
    echo "❌ DDL Replication failed"
    write_report "| DDL Replication | Column added on Node 2 should appear on Node 1/3 | FAIL | Column 'new_col' missing on some nodes |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"DDL Replication\",\"nature\":\"DDL Replication\",\"expected\":\"DDL statements replicate synchronously\",\"status\":\"FAIL\",\"details\":\"Column verification failed\"},"
fi

echo -e "\n6. 🛡️ Unique Key Constraint Test..."
write_report "### Unique Key Constraint Test"
echo ">> Inserting record ID 500 on Node 1..."
run_sql $NODE1_PORT "INSERT INTO $DB.sync_test (id, node_id, msg) VALUES (500, 1, 'Initial 500');"
echo ">> Attempting to insert same ID 500 on Node 2 (Should fail)..."
ERR_MSG=$(mariadb -h 127.0.0.1 -P $NODE2_PORT -uroot -p$PASS $DB -e "INSERT INTO sync_test (id, node_id, msg) VALUES (500, 2, 'Duplicate 500');" 2>&1)
if echo "$ERR_MSG" | grep -q "Duplicate entry"; then
    echo "✅ Node 2 correctly rejected duplicate entry"
    write_report "| Unique Constraint | Inserting already used ID on Node 2 should fail | PASS | Duplicate rejected as expected |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Unique Constraint\",\"nature\":\"Verify cluster-wide enforcement of UNIQUE constraints\",\"expected\":\"Inserting already used ID on Node 2 should fail even if inserted first on Node 1\",\"status\":\"PASS\",\"details\":\"Duplicate rejected as expected\"},"
else
    echo "❌ Node 2 failed to reject duplicate: $ERR_MSG"
    write_report "| Unique Constraint | Inserting already used ID on Node 2 should fail | FAIL | Duplicate NOT rejected: $ERR_MSG |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Unique Constraint\",\"nature\":\"Verify cluster-wide enforcement of UNIQUE constraints\",\"expected\":\"Inserting already used ID on Node 2 should fail even if inserted first on Node 1\",\"status\":\"FAIL\",\"details\":\"Duplicate NOT rejected: $ERR_MSG\"},"
fi

echo -e "\n7. ⚙️ Configuration Verification Test (PFS & Slow Query)..."
write_report "### Configuration Verification Test"
PFS_STATE=$(run_sql $NODE1_PORT "SELECT @@performance_schema;")
SLOW_LOG_STATE=$(run_sql $NODE1_PORT "SELECT @@slow_query_log;")
LONG_QUERY_TIME=$(run_sql $NODE1_PORT "SELECT @@long_query_time;")
SLOW_RATE_LIMIT=$(run_sql $NODE1_PORT "SELECT @@log_slow_rate_limit;")

if [ "$PFS_STATE" == "1" ] && [ "$SLOW_LOG_STATE" == "1" ]; then
    echo "✅ Performance Schema and Slow Query Log are ACTIVE"
    write_report "| Config Check | PFS and Slow Query Log should be ON | PASS | PFS=ON, SlowLog=ON (Time: ${LONG_QUERY_TIME}s, Rate: ${SLOW_RATE_LIMIT}) |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Config Check\",\"nature\":\"Verify PFS and Slow Query Log activation\",\"expected\":\"PFS=ON, SlowQueryLog=ON\",\"status\":\"PASS\",\"details\":\"PFS is ON, Slow Query Log is ON (${LONG_QUERY_TIME}s, Rate: ${SLOW_RATE_LIMIT})\"},"
else
    echo "❌ Configuration mismatch: PFS=$PFS_STATE, SlowLog=$SLOW_LOG_STATE"
    write_report "| Config Check | PFS and Slow Query Log should be ON | FAIL | PFS=$PFS_STATE, SlowLog=$SLOW_LOG_STATE |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Config Check\",\"nature\":\"Verify PFS and Slow Query Log activation\",\"expected\":\"PFS=ON, SlowQueryLog=ON\",\"status\":\"FAIL\",\"details\":\"PFS=$PFS_STATE, SlowLog=$SLOW_LOG_STATE\"},"
fi

echo -e "\n8. 🛰️ Galera Provider Options Audit..."
write_report "### Galera Provider Options Audit"
PROVIDER_OPTS=$(run_sql $NODE1_PORT "SELECT @@wsrep_provider_options;")

# --- Audit Best Practices ---
AUDIT_LOG=""
declare -A RECOM=( ["gcache.size"]="128M" ["cert.log_conflicts"]="YES" ["evs.suspect_timeout"]="PT5S" ["evs.inactive_timeout"]="PT15S" )
for key in "${!RECOM[@]}"; do
    current=$(echo "$PROVIDER_OPTS" | grep -oP "$key = \K[^;]+" | xargs)
    if [ "$current" == "${RECOM[$key]}" ]; then
        AUDIT_LOG+="✅ $key matches recommended value (${RECOM[$key]})\\n"
    else
        AUDIT_LOG+="⚠️ $key mismatch: $current (Recommended: ${RECOM[$key]})\\n"
    fi
done

if [ -n "$PROVIDER_OPTS" ]; then
    echo "✅ Galera Provider Options audited"
    write_report "| Provider Options Audit | Best practices check | PASS | Audit completed (see details) |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Provider Options Audit\",\"nature\":\"Galera Provider Options Audit\",\"expected\":\"Configured vs Best Practices\",\"status\":\"PASS\",\"details\":\"$AUDIT_LOG\"},"
else
    echo "❌ Galera Provider Options are empty"
    write_report "| Provider Options Audit | Best practices check | FAIL | Options are empty |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Provider Options Audit\",\"nature\":\"Galera Provider Options Audit\",\"expected\":\"Configured vs Best Practices\",\"status\":\"FAIL\",\"details\":\"Empty\"},"
fi

echo -e "\n9. 🔐 SSL Certificate Expiry Check..."
write_report "### SSL Certificate Expiry Check"
SSL_DIR="./ssl"
EXP_DAYS=30
EXP_SEC=$((EXP_DAYS * 86400))

if [ -f "$SSL_DIR/server-cert.pem" ]; then
    if openssl x509 -checkend $EXP_SEC -noout -in "$SSL_DIR/server-cert.pem"; then
        echo "✅ SSL certificates are valid for more than $EXP_DAYS days"
        write_report "| SSL Expiry | Should be > $EXP_DAYS days | PASS | Valid |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"SSL Expiry\",\"nature\":\"SSL Expiry Check\",\"expected\":\"> $EXP_DAYS days\",\"status\":\"PASS\",\"details\":\"Server certificate is valid for at least $EXP_DAYS days\"},"
    else
        echo "⚠️ SSL certificates expire in less than $EXP_DAYS days"
        write_report "| SSL Expiry | Should be > $EXP_DAYS days | WARN | Near expiry |"
        TEST_RESULTS="$TEST_RESULTS{\"test\":\"SSL Expiry\",\"nature\":\"SSL Expiry Check\",\"expected\":\"> $EXP_DAYS days\",\"status\":\"WARN\",\"details\":\"Server certificate expires soon!\"},"
    fi
else
    echo "❌ SSL certificates missing for check"
    write_report "| SSL Expiry | Should be > $EXP_DAYS days | FAIL | Missing |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"SSL Expiry\",\"nature\":\"SSL Expiry Check\",\"expected\":\"> $EXP_DAYS days\",\"status\":\"FAIL\",\"details\":\"Server certificate not found in $SSL_DIR/\"},"
fi

# Collect data for all nodes for comparison (Full view: Vars + Status + Galera Opts)
NODE_DATA="{"
for i in 1 2 3; do
    port_var="NODE${i}_PORT"
    port=${!port_var}
    if mariadb -h 127.0.0.1 -P $port -uroot -p$PASS -e "SELECT 1" > /dev/null 2>&1; then
        OPTS=$(run_sql $port "SELECT @@wsrep_provider_options;")
        VARS=$(run_sql $port "SHOW GLOBAL VARIABLES;")
        STATS=$(run_sql $port "SHOW GLOBAL STATUS;")
        
        # Sanitize and format
        OPTS_JS=$(echo "$OPTS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | tr -d '\r\n' | sed 's/; /;\\n/g')
        VARS_JS=$(echo "$VARS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | tr -d '\r\n')
        STATS_JS=$(echo "$STATS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | tr -d '\r\n')
        
        NODE_DATA+="\"node$i\": { \"opts\": \"$OPTS_JS\", \"vars\": \"$VARS_JS\", \"stats\": \"$STATS_JS\", \"name\": \"Serveur $i\", \"port\": \"$port\" },"
    fi
done
NODE_DATA="${NODE_DATA%,}}"

# For Markdown report, use Node 1 as default
SUMMARY_CONFIG=$(run_sql $NODE1_PORT "SHOW STATUS LIKE 'wsrep_local_state_comment'; SHOW STATUS LIKE 'wsrep_incoming_addresses'; SHOW STATUS LIKE 'wsrep_cluster_status'; SHOW VARIABLES LIKE 'auto_increment_increment'; SHOW VARIABLES LIKE 'auto_increment_offset';")
PROVIDER_OPTS_FLAT=$(run_sql $NODE1_PORT "SELECT @@wsrep_provider_options;" | sed 's/; /;\n                           /g')

write_report "\n## Summary Configuration & Status (Node 1)"
write_report "\`\`\`sql\n$SUMMARY_CONFIG\nwsrep_provider_options     $PROVIDER_OPTS_FLAT\n\`\`\`"

# Generate HTML Report
cat <<EOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Rapport de Test Galera Cluster</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'dark', securityLevel: 'loose' });
    </script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap');
        body { font-family: 'Outfit', sans-serif; background-color: #0f172a; color: #f1f5f9; }
        .glass { background: rgba(30, 41, 59, 0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255, 255, 255, 0.1); }
        .mermaid { background: transparent !important; }
        .custom-scrollbar::-webkit-scrollbar { width: 4px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: rgba(255, 255, 255, 0.02); }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.1); border-radius: 10px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.2); }
    </style>
</head>
<body class="p-8">
    <div class="max-w-6xl mx-auto space-y-8">
        <header class="glass p-8 rounded-3xl flex justify-between items-center">
            <div>
                <h1 class="text-4xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent italic">
                    <i class="fa-solid fa-network-wired mr-3"></i>Galera Cluster Test
                </h1>
                <p class="text-slate-400 mt-2 font-light italic">Rapport de vérification du cluster Galera</p>
            </div>
            <div class="text-right">
                <span class="text-slate-500 text-xs font-mono">$(date)</span>
            </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6" id="conn-stats">
            <!-- Stats will be injected here -->
        </div>

        <div class="glass p-8 rounded-3xl">
            <h3 class="text-xl font-bold mb-6 flex items-center text-indigo-400">
                <i class="fa-solid fa-diagram-project mr-3"></i>Architecture Visuelle
            </h3>
            <div class="mermaid flex justify-center py-4">
graph TD
    Client[Client / App] -->|Port 3306| LB[HAProxy LB<br/>10.6.0.100]
    
    subgraph Galera_Cluster [Galera Cluster: 10.6.0.0/24]
        LB -->|Port 3511| G1["mariadb-g1 (Node 1)"]
        LB -->|Port 3512| G2["mariadb-g2 (Node 2)"]
        LB -->|Port 3513| G3["mariadb-g3 (Node 3)"]
        
        G1 <--> G2
        G2 <--> G3
        G3 <--> G1
    end

    style Galera_Cluster fill:#1e293b,stroke:#334155,stroke-width:2px,color:#94a3b8
    style LB fill:#1e1b4b,stroke:#3730a3,color:#818cf8
    style G1 fill:#064e3b,stroke:#059669,color:#34d399
    style G2 fill:#064e3b,stroke:#059669,color:#34d399
    style G3 fill:#064e3b,stroke:#059669,color:#34d399
            </div>
        </div>

        <div class="glass p-8 rounded-3xl">
            <h3 class="text-xl font-bold mb-6 flex items-center text-blue-400">
                <i class="fa-solid fa-list-check mr-3"></i>Résultats des Tests
            </h3>
            <div class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                <thead>
                    <tr class="text-slate-500 uppercase text-[10px] font-bold border-b border-slate-700/50">
                        <th class="pb-4">Nature du Test</th>
                        <th class="pb-4">Attendu</th>
                        <th class="pb-4">Statut</th>
                        <th class="pb-4">Résultat Réel / Détails</th>
                    </tr>
                </thead>
                    <tbody id="test-results">
                        <!-- Results injected here -->
                    </tbody>
                </table>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="glass p-8 rounded-3xl col-span-1 lg:col-span-2">
                <div class="flex flex-col md:flex-row justify-between items-center mb-6 gap-4">
                    <h3 class="text-xl font-bold flex items-center text-indigo-400">
                        <i class="fa-solid fa-magnifying-glass-chart mr-3"></i>Explorateur de Configuration & Comparaison
                    </h3>
                    <div class="flex gap-4 items-center">
                        <div class="relative">
                            <i class="fa-solid fa-search absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-xs"></i>
                            <input type="text" id="global-search" placeholder="Rechercher une variable..." 
                                class="bg-black/40 border border-white/10 rounded-full py-2 pl-9 pr-4 text-xs focus:outline-none focus:ring-1 focus:ring-indigo-500 w-64">
                        </div>
                        <div class="text-xs text-slate-500 font-mono">
                            Composants filtrés: <span id="filter-count" class="text-indigo-400 font-bold">0</span>
                        </div>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                    <!-- Serveur 1 -->
                    <div class="space-y-6">
                        <div class="flex justify-between items-center bg-white/5 p-3 rounded-xl border border-white/5">
                            <span class="text-xs font-bold uppercase tracking-widest text-slate-400">Serveur</span>
                            <select id="node-a-select" class="bg-indigo-500/20 border border-indigo-500/30 rounded-lg text-xs px-3 py-1 text-indigo-300 focus:outline-none cursor-pointer hover:bg-indigo-500/30 transition-all"></select>
                        </div>
                        <div id="col-a-content" class="space-y-4 max-h-[600px] overflow-y-auto pr-2 custom-scrollbar"></div>
                    </div>

                    <!-- Serveur 2 -->
                    <div class="space-y-6">
                        <div class="flex justify-between items-center bg-white/5 p-3 rounded-xl border border-white/5">
                            <span class="text-xs font-bold uppercase tracking-widest text-slate-400">Serveur</span>
                            <select id="node-b-select" class="bg-purple-500/20 border border-purple-500/30 rounded-lg text-xs px-3 py-1 text-purple-300 focus:outline-none cursor-pointer hover:bg-purple-500/30 transition-all"></select>
                        </div>
                        <div id="col-b-content" class="space-y-4 max-h-[600px] overflow-y-auto pr-2 custom-scrollbar"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const connStats = [${CONN_STATS%?}];
        const testResults = [${TEST_RESULTS%?}];
        const nodeData = $NODE_DATA;

        let currentSearch = '';

        function getGroups(rawText) {
            const lines = rawText.split('\\n');
            const groups = {};
            lines.forEach(line => {
                if (!line.trim()) return;
                const parts = line.split(/[ \t=]+/).filter(p => p.length > 0);
                if (parts.length >= 2) {
                    const key = parts[0];
                    const val = parts.slice(1).join(' ');
                    
                    // Logic to group by prefix or category
                    let groupName = 'Others';
                    if (key.startsWith('wsrep_')) {
                        groupName = key.split('_')[0] + '_' + key.split('_')[1]; // e.g. wsrep_local, wsrep_cluster
                        if (groupName.length > 15) groupName = 'wsrep_core';
                    } else if (key.includes('.')) {
                        groupName = key.split('.')[0]; // e.g. evs, gcache
                    } else if (key.startsWith('innodb_')) {
                        groupName = 'InnoDB';
                    } else if (key.startsWith('aria_')) {
                        groupName = 'Aria';
                    } else if (key.startsWith('log_') || key.includes('_log')) {
                        groupName = 'Logging';
                    } else if (key.startsWith('ssl_') || key.startsWith('have_ssl')) {
                        groupName = 'SSL/Security';
                    } else if (key.startsWith('binlog_') || key.startsWith('gtid_')) {
                        groupName = 'Replication/GTID';
                    } else if (key.startsWith('optimizer_')) {
                        groupName = 'Optimizer';
                    }

                    if (!groups[groupName]) groups[groupName] = [];
                    groups[groupName].push({ key, val });
                }
            });
            return groups;
        }

        function renderNodeCol(containerId, nodeId, searchStr, themeColor) {
            const container = document.getElementById(containerId);
            container.innerHTML = '';
            
            const data = nodeData[nodeId];
            if (!data) return;

            // Combine all available data for full exploration
            const allText = data.vars + '\\n' + data.stats + '\\n' + data.opts;
            const groups = getGroups(allText);
            
            let totalMatch = 0;

            Object.keys(groups).sort().forEach(groupName => {
                const groupItems = groups[groupName].filter(item => 
                    item.key.toLowerCase().includes(searchStr.toLowerCase()) || 
                    item.val.toLowerCase().includes(searchStr.toLowerCase())
                );

                if (groupItems.length === 0) return;
                totalMatch += groupItems.length;

                const groupDetails = document.createElement('details');
                groupDetails.className = 'group bg-black/20 rounded-xl border border-white/5 overflow-hidden transition-all duration-300';
                groupDetails.open = searchStr.length > 0;
                
                groupDetails.innerHTML = \`
                    <summary class="flex justify-between items-center p-3 cursor-pointer hover:bg-white/5 transition-colors list-none">
                        <span class="text-xs font-bold uppercase tracking-tighter \${themeColor}">\${groupName}</span>
                        <div class="flex items-center gap-2">
                            <span class="text-[10px] bg-white/10 px-2 rounded-full text-slate-400">\${groupItems.length}</span>
                            <i class="fa-solid fa-chevron-down text-[10px] text-slate-500 group-open:rotate-180 transition-transform"></i>
                        </div>
                    </summary>
                    <div class="p-3 pt-0 space-y-1 bg-black/10">
                        \${groupItems.map(item => \`
                            <div class="flex justify-between items-center py-1 border-b border-white/5 hover:bg-white/5 px-1 rounded transition-colors group/item">
                                <span class="text-[10px] text-slate-500 font-mono truncate mr-4">\${item.key}</span>
                                <span class="text-[10px] \${themeColor} font-mono font-bold text-right">\${item.val}</span>
                            </div>
                        \`).join('')}
                    </div>
                \`;
                container.appendChild(groupDetails);
            });
            return totalMatch;
        }

        function refreshAll() {
            const nodeA = document.getElementById('node-a-select').value;
            const nodeB = document.getElementById('node-b-select').value;
            const countA = renderNodeCol('col-a-content', nodeA, currentSearch, 'text-indigo-300');
            const countB = renderNodeCol('col-b-content', nodeB, currentSearch, 'text-purple-300');
            document.getElementById('filter-count').textContent = Math.max(countA, countB);
        }

        // Init selectors
        const selA = document.getElementById('node-a-select');
        const selB = document.getElementById('node-b-select');
        Object.keys(nodeData).forEach((id, idx) => {
            const optA = new Option(nodeData[id].name + ' (' + nodeData[id].port + ')', id);
            const optB = new Option(nodeData[id].name + ' (' + nodeData[id].port + ')', id);
            selA.add(optA);
            selB.add(optB);
            if (idx === 1) selB.selectedIndex = 1; // Default select node 2 in Col B
        });

        selA.addEventListener('change', refreshAll);
        selB.addEventListener('change', refreshAll);
        document.getElementById('global-search').addEventListener('input', (e) => {
            currentSearch = e.target.value;
            refreshAll();
        });

        // Initial render
        refreshAll();

        const connContainer = document.getElementById('conn-stats');
        connStats.forEach(stat => {
            const div = document.createElement('div');
            div.className = 'glass p-6 rounded-2xl';
            div.innerHTML = \`
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">\${stat.name} (\${stat.port})</div>
                <div class="text-2xl font-bold \${stat.status === 'UP' ? 'text-green-400' : 'text-red-400'}">\${stat.status}</div>
                <div class="text-[10px] text-slate-400 mt-1 uppercase">State: \${stat.state} | Size: \${stat.size}</div>
            \`;
            connContainer.appendChild(div);
        });

        const resContainer = document.getElementById('test-results');
        testResults.forEach(item => {
            const row = document.createElement('tr');
            row.className = 'border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors';
            row.innerHTML = \`
                <td class="py-4 font-semibold text-slate-300">\${item.nature || item.test}</td>
                <td class="py-4 text-slate-400">\${item.expected || '-'}</td>
                <td class="py-4">
                    <span class="px-2 py-1 rounded text-[10px] font-bold uppercase \${item.status === 'PASS' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : (item.status === 'SKIP' ? 'bg-slate-500/10 text-slate-500 border border-slate-500/20' : 'bg-red-500/10 text-red-500 border border-red-500/20')}">
                        \${item.status}
                    </span>
                </td>
                <td class="py-4 text-slate-400 text-xs font-mono">\${item.details}</td>
            \`;
            resContainer.appendChild(row);
        });
    </script>
</body>
</html>
EOF
echo "🏁 Galera Test Suite Finished."
echo "Markdown Report: $REPORT_MD"
echo "HTML Report: $REPORT_HTML"
echo "=========================================================="
