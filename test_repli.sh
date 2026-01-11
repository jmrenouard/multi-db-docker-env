#!/bin/bash

# Configuration
MASTER_PORT=3411
SLAVE1_PORT=3412
SLAVE2_PORT=3413
USER="root"
PASS="rootpass"
DB="test_repli_db"

# Create reports directory if it doesn't exist
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

# Report filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_MD="$REPORT_DIR/test_repli_$TIMESTAMP.md"
REPORT_HTML="$REPORT_DIR/test_repli_$TIMESTAMP.html"

echo "=========================================================="
echo "🚀 MariaDB Replication Test Suite"
echo "=========================================================="

# Function to write to report
write_report() {
    echo -e "$1" >> "$REPORT_MD"
}

# Initialize report
cat <<EOF > "$REPORT_MD"
# MariaDB Replication Test Report
**Date:** $(date)

EOF

# Function to execute SQL
run_sql() {
    local port=$1
    local query=$2
    mariadb -h 127.0.0.1 -P $port -u$USER -p$PASS -sN -e "$query" 2>/dev/null
}

# Data for HTML report
CONN_STATS=""
REPL_INFO=""
TEST_RESULTS=""

echo "1. ⏳ Waiting for containers and replication to be ready (max 90s)..."
MAX_WAIT=90
START_WAIT=$(date +%s)
READY=false

while [ $(($(date +%s) - START_WAIT)) -lt $MAX_WAIT ]; do
    ALL_UP=true
    REPL_OK=true
    
    # Check Master
    if ! run_sql $MASTER_PORT "SELECT 1" > /dev/null 2>&1; then ALL_UP=false; fi
    
    # Check Slaves and Replication Status
    for port in $SLAVE1_PORT $SLAVE2_PORT; do
        if ! run_sql $port "SELECT 1" > /dev/null 2>&1; then
            ALL_UP=false
        else
            # Use raw mariadb to ensure labels are present for grep
            IO=$(mariadb -h 127.0.0.1 -P $port -u$USER -p$PASS -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
            SQL=$(mariadb -h 127.0.0.1 -P $port -u$USER -p$PASS -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
            if [ "$IO" != "Yes" ] || [ "$SQL" != "Yes" ]; then
                REPL_OK=false
            fi
        fi
    done
    
    if $ALL_UP && $REPL_OK; then
        READY=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$READY" = false ]; then
    echo "❌ Timeout: Containers or replication not ready after 90s."
    write_report "## ❌ Pre-flight Check Failed\nTimeout: Containers or replication not ready after 90s."
    exit 1
fi

echo "✅ Environment is ready. Starting tests..."

write_report "| Nom du Nœud | Port | Statut | SSL Cipher |"
write_report "| --- | --- | --- | --- |"
for role in "Master:$MASTER_PORT" "Slave1:$SLAVE1_PORT" "Slave2:$SLAVE2_PORT"; do
    IFS=":" read -r name port <<< "$role"
    status="DOWN"
    ssl="N/A"
    if run_sql $port "SELECT 1" > /dev/null; then
        status="UP"
        CIPHER=$(mariadb -h 127.0.0.1 -P $port -u$USER -p$PASS -sN -e "SHOW STATUS LIKE 'Ssl_cipher';" | awk '{print $2}')
        if [ ! -z "$CIPHER" ] && [ "$CIPHER" != "NULL" ]; then
            ssl="$CIPHER"
        else
            ssl="DISABLED"
        fi
        write_report "| $name | $port | UP | $ssl |"
    else
        write_report "| $name | $port | DOWN | N/A |"
    fi
    CONN_STATS="$CONN_STATS{\"name\":\"$name\",\"port\":\"$port\",\"status\":\"$status\",\"ssl\":\"$ssl\"},"
done

# Populate variables for HTML report and MD summary
MASTER_VARS=$(run_sql $MASTER_PORT "SHOW VARIABLES LIKE '%binlog%'; SHOW VARIABLES LIKE '%gtid%';")
MASTER_STATUS=$(run_sql $MASTER_PORT "SHOW MASTER STATUS\G")
MASTER_STATUS_JS=$(echo "$MASTER_STATUS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | tr -d '\r\n' | sed 's/\\n$/ /')
MASTER_VARS_JS=$(echo "$MASTER_VARS" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | tr -d '\r\n' | sed 's/\\n$/ /')

for port in $SLAVE1_PORT $SLAVE2_PORT; do
    REPL_STATUS=$(run_sql $port "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Master_Host|Seconds_Behind_Master")
    REPL_INFO="$REPL_INFO{\"port\":\"$port\",\"status\":\"$(echo "$REPL_STATUS" | tr '\n' ' ')\"},"
done

write_report "\n## Sections pour la réplication (master & slave)"
write_report "### Detailed Master Status\n\`\`\`sql\n$(mariadb -h 127.0.0.1 -P $MASTER_PORT -u$USER -p$PASS -e "SHOW MASTER STATUS\G")\n\`\`\`"
SLAVE1_FULL=$(mariadb -h 127.0.0.1 -P $SLAVE1_PORT -u$USER -p$PASS -e "SHOW SLAVE STATUS\G")
write_report "### Detailed Slave 1 Status\n\`\`\`sql\n$SLAVE1_FULL\n\`\`\`"
SLAVE2_FULL=$(mariadb -h 127.0.0.1 -P $SLAVE2_PORT -u$USER -p$PASS -e "SHOW SLAVE STATUS\G")
write_report "### Detailed Slave 2 Status\n\`\`\`sql\n$SLAVE2_FULL\n\`\`\`"

echo -e "\n5. 🧪 Performing Data Replication Test..."
write_report "\n## Résultats des tests de réplication"
write_report "| Nature du Test | Attendu | Statut | Résultat Réel / Détails |"
write_report "| --- | --- | --- | --- |"
echo ">> Creating database '$DB' and table on Master..."
run_sql $MASTER_PORT "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB; USE $DB; CREATE TABLE test_table (id INT AUTO_INCREMENT PRIMARY KEY, msg VARCHAR(255), ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
run_sql $MASTER_PORT "INSERT INTO $DB.test_table (msg) VALUES ('Hello from Master at $(date)');"

echo ">> Waiting 2 seconds for replication..."
sleep 2

echo ">> Checking Slave 1..."
VAL=$(run_sql $SLAVE1_PORT "SELECT msg FROM $DB.test_table LIMIT 1;" | tr -d '\n\r' | sed 's/"/\\"/g')
if [ -z "$VAL" ]; then
    ROW_COUNT=0
else
    ROW_COUNT=1
fi

if [ "$ROW_COUNT" -eq 1 ]; then
    echo "✅ Data replicated successfully to Slave 1"
    write_report "| Master -> Slave 1 Sync | Write on Master should replicate to Slave 1 | PASS | Row found on Slave 1 |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Replication Master->Slave 1\",\"nature\":\"Replication Sync (Slave 1)\",\"expected\":\"Data replicated from Master\",\"status\":\"PASS\",\"details\":\"Row found with value: $VAL\"},"
else
    echo "❌ Data NOT found on Slave 1"
    write_report "| Master -> Slave 1 Sync | Write on Master should replicate to Slave 1 | FAIL | Row NOT found on Slave 1 |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Replication Master->Slave 1\",\"nature\":\"Replication Sync (Slave 1)\",\"expected\":\"Data replicated from Master\",\"status\":\"FAIL\",\"details\":\"Row NOT found\"},"
fi

echo ">> Checking Slave 2..."
VAL_S2=$(run_sql $SLAVE2_PORT "SELECT msg FROM $DB.test_table LIMIT 1;" | tr -d '\n\r' | sed 's/"/\\"/g')
if [ -z "$VAL_S2" ]; then
    ROW_COUNT_S2=0
else
    ROW_COUNT_S2=1
fi

if [ "$ROW_COUNT_S2" -eq 1 ]; then
    echo "✅ Data replicated successfully to Slave 2"
    write_report "| Master -> Slave 2 Sync | Write on Master should replicate to Slave 2 | PASS | Row found on Slave 2 |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Replication Master->Slave 2\",\"nature\":\"Replication Sync (Slave 2)\",\"expected\":\"Data replicated from Master\",\"status\":\"PASS\",\"details\":\"Row found with value: $VAL_S2\"},"
else
    echo "❌ Data NOT found on Slave 2"
    write_report "| Master -> Slave 2 Sync | Write on Master should replicate to Slave 2 | FAIL | Row NOT found on Slave 2 |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Replication Master->Slave 2\",\"nature\":\"Replication Sync (Slave 2)\",\"expected\":\"Data replicated from Master\",\"status\":\"FAIL\",\"details\":\"Row NOT found\"},"
fi

echo -e "\n6. 🛡️ Read-Only Test on Slaves..."
# Create a temporary non-super user to test read_only (which root bypasses)
run_sql $SLAVE1_PORT "CREATE USER IF NOT EXISTS 'test_ro'@'%' IDENTIFIED BY 'testpass'; GRANT INSERT ON $DB.* TO 'test_ro'@'%'; FLUSH PRIVILEGES;"
RO_ERR=0
mariadb -h 127.0.0.1 -P $SLAVE1_PORT -utest_ro -ptestpass $DB -e "INSERT INTO test_table (msg) VALUES ('Illegal write from non-super user');" 2>/dev/null || RO_ERR=1
run_sql $SLAVE1_PORT "DROP USER 'test_ro'@'%';"

if [ "$RO_ERR" -eq 0 ]; then
    echo "❌ ERROR: Slave 1 accepted a write (should be read-only for non-super users)"
    write_report "| Slave Read-Only | Write on Slave should be rejected | FAIL | Slave accepted the write from non-super user |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Slave Read-Only\",\"nature\":\"Read-Only Constraint\",\"expected\":\"Slave should reject writes for non-super users\",\"status\":\"FAIL\",\"details\":\"Slave 1 incorrectly accepted the write\"},"
else
    echo "✅ Slave 1 correctly rejected the write (Read-only mode enforced)"
    write_report "| Slave Read-Only | Write on Slave should be rejected | PASS | Correctly rejected write from non-super user |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"Slave Read-Only\",\"nature\":\"Read-Only Constraint\",\"expected\":\"Slave should reject writes for non-super users\",\"status\":\"PASS\",\"details\":\"Slave 1 rejected the write as expected\"},"
fi

echo -e "\n7. 🔐 SSL Connection Verification..."
CIPHER=$(mariadb -h 127.0.0.1 -P $MASTER_PORT -u$USER -p$PASS -sN -e "SHOW STATUS LIKE 'Ssl_cipher';" | awk '{print $2}')
if [[ "$CIPHER" != "" ]] && [[ "$CIPHER" != "NULL" ]]; then
    echo "✅ SSL Connection verified on Master (Cipher: $CIPHER)"
    write_report "| SSL Connectivity (Master) | Node should support SSL | PASS | Connected with $CIPHER |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"SSL Connectivity Master\",\"nature\":\"SSL Status Check\",\"expected\":\"Connection should be encrypted\",\"status\":\"PASS\",\"details\":\"Connected to Master using SSL ($CIPHER)\"},"
else
    echo "❌ SSL NOT active on Master"
    write_report "| SSL Connectivity (Master) | Node should support SSL | FAIL | SSL Cipher is empty/null |"
    TEST_RESULTS="$TEST_RESULTS{\"test\":\"SSL Connectivity Master\",\"nature\":\"SSL Status Check\",\"expected\":\"Connection should be encrypted\",\"status\":\"FAIL\",\"details\":\"SSL not active on Master\"},"
fi

# Generate HTML Report
cat <<EOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Rapport de Test de Réplication MariaDB</title>
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
    </style>
</head>
<body class="p-8">
    <div class="max-w-6xl mx-auto space-y-8">
        <header class="glass p-8 rounded-3xl flex justify-between items-center">
            <div>
                <h1 class="text-4xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent italic">
                    <i class="fa-solid fa-sync mr-3"></i>Replication Test
                </h1>
                <p class="text-slate-400 mt-2 font-light italic">Rapport de vérification du cluster de réplication</p>
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
    Client_W[Write Client] -->|Port 3406| LB[HAProxy LB<br/>10.5.0.100]
    Client_R[Read Client] -->|Port 3407| LB
    
    subgraph Replication_Topology [Replication Cluster: 10.5.0.0/24]
        LB -->|Writes| M1["mariadb-m1 (Master)"]
        LB -->|Read RR| S1["mariadb-s1 (Slave 1)"]
        LB -->|Read RR| S2["mariadb-s2 (Slave 2)"]
        
        M1 --"Async (GTID)"--> S1
        M1 --"Async (GTID)"--> S2
    end

    style Replication_Topology fill:#1e293b,stroke:#334155,stroke-width:2px,color:#94a3b8
    style LB fill:#1e1b4b,stroke:#3730a3,color:#818cf8
    style M1 fill:#4c1d95,stroke:#8b5cf6,color:#ddd6fe
    style S1 fill:#064e3b,stroke:#059669,color:#34d399
    style S2 fill:#064e3b,stroke:#059669,color:#34d399
            </div>
        </div>

        <div class="glass p-8 rounded-3xl">
            <h3 class="text-xl font-bold mb-6 flex items-center text-blue-400">
                <i class="fa-solid fa-flask mr-3"></i>Résultats des Tests
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
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-cyan-400"><i class="fa-solid fa-server mr-3"></i>Master Status</h3>
                <pre class="p-4 bg-black/40 rounded text-[10px] font-mono whitespace-pre overflow-x-auto text-cyan-300" id="master-status"></pre>
            </div>
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-purple-400"><i class="fa-solid fa-microchip mr-3"></i>Master Variables</h3>
                <pre class="p-4 bg-black/40 rounded text-[10px] font-mono whitespace-pre overflow-x-auto text-purple-300" id="master-vars"></pre>
            </div>
        </div>
    </div>

    <script>
        const connStats = [${CONN_STATS%?}];
        const testResults = [${TEST_RESULTS%?}];
        const masterStatusRaw = "$MASTER_STATUS_JS";
        const masterVarsRaw = "$MASTER_VARS_JS";

        document.getElementById('master-status').textContent = masterStatusRaw.replace(/\\n/g, '\n');
        document.getElementById('master-vars').textContent = masterVarsRaw.replace(/\\n/g, '\n');

        const connContainer = document.getElementById('conn-stats');
        connStats.forEach(stat => {
            const div = document.createElement('div');
            div.className = 'glass p-6 rounded-2xl';
            div.innerHTML = \`
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">\${stat.name} (Port \${stat.port})</div>
                <div class="text-2xl font-bold \${stat.status === 'UP' ? 'text-green-400' : 'text-red-400'}">\${stat.status}</div>
                <div class="text-xs text-slate-400 mt-1">SSL: \${stat.ssl}</div>
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
                            <span class="px-2 py-1 rounded text-[10px] font-bold uppercase \${item.status === 'PASS' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : 'bg-red-500/10 text-red-500 border border-red-500/20'}">
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

echo -e "\n=========================================================="
echo "🏁 Test Suite Finished."
echo "Markdown Report: $REPORT_MD"
echo "HTML Report: $REPORT_HTML"
echo "=========================================================="
