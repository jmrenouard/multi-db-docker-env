#!/bin/bash

# Configuration defaults
DB_USER="root"
DB_PASS="rootpass"
DB_NAME="sbtest"
THREADS=4
REPORT_INTERVAL=10

# Helper for color output
echo_title() { echo -e "\n\033[1;36m>> $1\033[0m"; }
echo_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
echo_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

usage() {
    echo "Usage: $0 [light|standard|read|write] [prepare|run|cleanup]"
    echo ""
    echo "Profiles:"
    echo "  light     : 1 table, 1,000 rows, 10s run (Quick check)"
    echo "  standard  : 1 table, 100,000 rows, 60s run"
    echo "  read      : Read-only intense (Standard size)"
    echo "  write     : Write-only intense (Standard size)"
    exit 1
}

if [ "$#" -ne 2 ]; then usage; fi

PROFILE=$1
ACTION=$2
CLUSTER="galera"

# Internal HAProxy service name and port within docker network
TARGET_HOST="haproxy_galera"
TARGET_PORT=3306

# Define Profile Settings
case $PROFILE in
    light)
        TABLES=1
        TABLE_SIZE=1000
        TIME=10
        SCRIPT="oltp_read_write"
        ;;
    standard)
        TABLES=1
        TABLE_SIZE=100000
        TIME=60
        SCRIPT="oltp_read_write"
        ;;
    read)
        TABLES=1
        TABLE_SIZE=100000
        TIME=60
        SCRIPT="oltp_read_only"
        ;;
    write)
        TABLES=1
        TABLE_SIZE=100000
        TIME=60
        SCRIPT="oltp_write_only"
        ;;
    *)
        echo_error "Unknown profile: $PROFILE"; usage
        ;;
esac

CLIENT_CONTAINER="mariadb-galera_01-1"
COMMAND="sysbench $SCRIPT --db-driver=mysql --mysql-host=$TARGET_HOST --mysql-port=$TARGET_PORT --mysql-user=$DB_USER --mysql-password=$DB_PASS --mysql-db=$DB_NAME --tables=$TABLES --table-size=$TABLE_SIZE --threads=$THREADS --time=$TIME --report-interval=$REPORT_INTERVAL"

case $ACTION in
    prepare)
        echo_title "Preparing Galera cluster for $PROFILE test..."
        PREP_HOST="10.6.0.11"
        docker exec -it $CLIENT_CONTAINER mariadb -h$PREP_HOST -uroot -p$DB_PASS -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME;"
        echo "Creating $TABLES tables..."
        docker exec -it $CLIENT_CONTAINER $COMMAND --mysql-host=$PREP_HOST --threads=1 prepare
        echo_success "Preparation complete."
        ;;
    run)
        echo_title "Running $PROFILE performance test on Galera..."
        mkdir -p reports
        RAW_OUT="perf_raw_galera_$(date +%Y%m%d_%H%M%S).txt"
        REPORT_FILE="reports/test_perf_galera_$(date +%Y%m%d_%H%M%S).html"
        START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Capture Galera stats before (Aggregate from all nodes)
        BF_BEFORE=0; CERT_BEFORE=0
        NODES=("mariadb-galera_01-1" "mariadb-galera_02-1" "mariadb-galera_03-1")
        for node in "${NODES[@]}"; do
            bf=$(docker exec $node mariadb -h 127.0.0.1 -uroot -p$DB_PASS -N -s -e "SHOW STATUS LIKE 'wsrep_local_bf_aborts';" | awk '{print $2}' || echo 0)
            cert=$(docker exec $node mariadb -h 127.0.0.1 -uroot -p$DB_PASS -N -s -e "SHOW STATUS LIKE 'wsrep_local_cert_failures';" | awk '{print $2}' || echo 0)
            BF_BEFORE=$((BF_BEFORE + bf)); CERT_BEFORE=$((CERT_BEFORE + cert))
        done

        # Run sysbench
        docker exec -it $CLIENT_CONTAINER $COMMAND run | tee "$RAW_OUT"
        
        # Capture Galera stats after
        BF_AFTER=0; CERT_AFTER=0
        for node in "${NODES[@]}"; do
            bf=$(docker exec $node mariadb -h 127.0.0.1 -uroot -p$DB_PASS -N -s -e "SHOW STATUS LIKE 'wsrep_local_bf_aborts';" | awk '{print $2}' || echo 0)
            cert=$(docker exec $node mariadb -h 127.0.0.1 -uroot -p$DB_PASS -N -s -e "SHOW STATUS LIKE 'wsrep_local_cert_failures';" | awk '{print $2}' || echo 0)
            BF_AFTER=$((BF_AFTER + bf)); CERT_AFTER=$((CERT_AFTER + cert))
        done
        BF_DIFF=$((BF_AFTER - BF_BEFORE)); CERT_DIFF=$((CERT_AFTER - CERT_BEFORE))

        echo_title "Collecting Container Logs..."
        LOGS_OUT=""
        for node in "${NODES[@]}"; do
            # 💡 Pro Tip: Conflict logs often go to the file defined by log_error, not always to docker logs
            log_file=$(docker exec "$node" mariadb -h 127.0.0.1 -uroot -p$DB_PASS -N -s -e "SHOW VARIABLES LIKE 'log_error';" 2>/dev/null | awk '{print $2}')
            
            if [ -n "$log_file" ]; then
                # Get logs from file (conflicts) AND docker logs (system/startup errors)
                node_logs_f=$(docker exec "$node" grep -iE "error|fatal|critical|conflict|certification|brute force" "$log_file" | tail -n 10)
                node_logs_d=$(docker logs --since "$START_TIME" "$node" 2>&1 | grep -iE "error|fatal|critical|conflict|certification|brute force" | tail -n 10)
                node_logs=$(echo -e "$node_logs_d\n$node_logs_f" | grep -v "^$" | sort -u || echo "No relevant issues found.")
            else
                node_logs=$(docker logs --since "$START_TIME" "$node" 2>&1 | grep -iE "error|fatal|critical|conflict|certification|brute force" | tail -n 20 || echo "No relevant issues found.")
            fi

            [ -z "$node_logs" ] && node_logs="No relevant issues found."

            LOGS_OUT="$LOGS_OUT
--- $node ---
$node_logs
"
        done

        # Extraction logic
        TPS=$(grep "transactions:" "$RAW_OUT" | awk '{print $3}' | tr -d '()' | tr -d '\r')
        QPS=$(grep "queries:" "$RAW_OUT" | awk '{print $3}' | tr -d '()' | tr -d '\r')
        Q_READ=$(grep "read:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        Q_WRITE=$(grep "write:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        Q_OTHER=$(grep "other:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        TOTAL_QUERIES=$(grep "total:" "$RAW_OUT" | head -n1 | awk '{print $2}' | tr -d '\r')
        L_MIN=$(grep "min:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        L_AVG=$(grep "avg:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        L_MAX=$(grep "max:" "$RAW_OUT" | awk '{print $2}' | tr -d '\r')
        L_P95=$(grep "95th percentile:" "$RAW_OUT" | awk '{print $3}' | tr -d '\r')
        TOTAL_EVENTS=$(grep "total number of events:" "$RAW_OUT" | awk '{print $5}' | tr -d '\r')
        TOTAL_TIME=$(grep "total time:" "$RAW_OUT" | awk '{print $3}' | tr -d 's' | tr -d '\r')
        IGN_ERR=$(grep "ignored errors:" "$RAW_OUT" | awk '{print $3}' | tr -d '\r')

        echo_title "Generating HTML Report..."
        cat <<EOF > "$REPORT_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Tester Galera - Rapport de Performance</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap');
        body { font-family: 'Outfit', sans-serif; background-color: #0f172a; color: #f1f5f9; }
        .glass { background: rgba(30, 41, 59, 0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255, 255, 255, 0.1); }
    </style>
</head>
<body class="p-8">
    <div class="max-w-6xl mx-auto space-y-8">
        <header class="glass p-8 rounded-3xl flex justify-between items-center">
            <div>
                <h1 class="text-4xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent italic">
                    <i class="fa-solid fa-bolt-lightning mr-3"></i>Tester Galera
                </h1>
                <p class="text-slate-400 mt-2 font-light italic">Audit de performance du cluster Galera via HAProxy</p>
            </div>
            <div class="text-right">
                <span class="px-4 py-1 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 text-sm font-semibold mb-2 block lowercase">Profil: $PROFILE</span>
                <span class="text-slate-500 text-xs font-mono">$(date)</span>
            </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            <!-- KPIs -->
            <div class="glass p-6 rounded-2xl">
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">Throughput</div>
                <div class="text-3xl font-bold text-cyan-400">$TPS <span class="text-xs font-normal">tps</span></div>
            </div>
            <div class="glass p-6 rounded-2xl">
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">Query Load</div>
                <div class="text-3xl font-bold text-blue-400">$QPS <span class="text-xs font-normal">qps</span></div>
            </div>
            <div class="glass p-6 rounded-2xl">
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">Avg Latency</div>
                <div class="text-3xl font-bold text-purple-400">$L_AVG <span class="text-xs font-normal text-slate-500 uppercase">ms</span></div>
            </div>
            <div class="glass p-6 rounded-2xl border-l-4 border-rose-500/50">
                <div class="text-slate-500 text-xs uppercase font-bold mb-2">Ignored Errors</div>
                <div class="text-3xl font-bold text-rose-400">$IGN_ERR</div>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Query Metrics -->
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-blue-400">
                    <i class="fa-solid fa-magnifying-glass-chart mr-3"></i>Query Metrics
                </h3>
                <div class="space-y-6">
                    <div>
                        <div class="flex justify-between mb-2">
                            <span class="text-slate-400 font-semibold uppercase text-xs tracking-wider">READ Queries</span>
                            <span class="text-blue-400 font-bold">$Q_READ</span>
                        </div>
                        <div class="w-full bg-slate-800 rounded-full h-2">
                            <div class="bg-blue-500 h-2 rounded-full shadow-[0_0_10px_rgba(59,130,246,0.5)]" style="width: $(echo "scale=2; $Q_READ*100/$TOTAL_QUERIES" | bc)%"></div>
                        </div>
                    </div>
                    <div>
                        <div class="flex justify-between mb-2">
                            <span class="text-slate-400 font-semibold uppercase text-xs tracking-wider">WRITE Queries</span>
                            <span class="text-cyan-400 font-bold">$Q_WRITE</span>
                        </div>
                        <div class="w-full bg-slate-800 rounded-full h-2">
                            <div class="bg-cyan-500 h-2 rounded-full shadow-[0_0_10px_rgba(34,211,238,0.5)]" style="width: $(echo "scale=2; $Q_WRITE*100/$TOTAL_QUERIES" | bc)%"></div>
                        </div>
                    </div>
                    <div>
                        <div class="flex justify-between mb-2">
                            <span class="text-slate-400 font-semibold uppercase text-xs tracking-wider">OTHER Queries</span>
                            <span class="text-purple-400 font-bold">$Q_OTHER</span>
                        </div>
                        <div class="w-full bg-slate-800 rounded-full h-2">
                            <div class="bg-purple-500 h-2 rounded-full shadow-[0_0_10px_rgba(168,85,247,0.5)]" style="width: $(echo "scale=2; $Q_OTHER*100/$TOTAL_QUERIES" | bc)%"></div>
                        </div>
                    </div>
                </div>
            </div>
            <!-- Latency Profile -->
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-cyan-400"><i class="fa-solid fa-chart-line mr-3"></i>Latency Profile (ms)</h3>
                <div class="h-64"><canvas id="latencyChart"></canvas></div>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-amber-400"><i class="fa-solid fa-brain mr-3"></i>Conflict Intelligence</h3>
                <div class="grid grid-cols-2 gap-4">
                    <div class="p-4 bg-amber-500/5 rounded-2xl border border-amber-500/10">
                        <div class="text-slate-500 text-[10px] uppercase font-bold mb-1">Cert. Failures</div>
                        <div class="text-2xl font-bold text-amber-400">$CERT_DIFF</div>
                    </div>
                    <div class="p-4 bg-orange-500/5 rounded-2xl border border-orange-500/10">
                        <div class="text-slate-500 text-[10px] uppercase font-bold mb-1">BF Aborts</div>
                        <div class="text-2xl font-bold text-orange-400">$BF_DIFF</div>
                    </div>
                </div>
                <p class="mt-4 text-[10px] text-slate-400 italic">Deltas mesurés sur l'ensemble du cluster pendant le test.</p>
            </div>

            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-6 flex items-center text-rose-400"><i class="fa-solid fa-shield-virus mr-3"></i>Cluster Logs Health</h3>
                <div class="p-4 bg-black/40 rounded-xl border border-rose-500/20 h-48 overflow-y-auto">
                    <pre class="text-[10px] text-rose-300/80 font-mono italic whitespace-pre-wrap">$LOGS_OUT</pre>
                </div>
            </div>
        </div>

        <details class="glass p-6 rounded-2xl text-slate-500">
            <summary class="cursor-pointer font-bold uppercase text-xs">Raw sysbench output</summary>
            <pre class="mt-4 p-4 bg-black/40 rounded text-[10px] font-mono whitespace-pre overflow-x-auto">$(cat "$RAW_OUT")</pre>
        </details>
    </div>
    <script>
        new Chart(document.getElementById('latencyChart'), {
            type: 'bar',
            data: {
                labels: ['Min', 'Avg', '95th', 'Max'],
                datasets: [{
                    label: 'Latency (ms)',
                    data: [$L_MIN, $L_AVG, $L_P95, $L_MAX],
                    backgroundColor: 'rgba(34, 211, 238, 0.2)',
                    borderColor: '#22d3ee',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: { beginAtZero: true, ticks: { callback: function(value) { return value + ' ms'; } } }
                }
            }
        });
    </script>
</body>
</html>
EOF
        echo_success "Report generated: $REPORT_FILE"
        rm "$RAW_OUT"
        ;;
    cleanup)
        echo_title "Cleaning up Galera cluster..."
        docker exec -it $CLIENT_CONTAINER $COMMAND cleanup
        echo_success "Cleanup complete."
        ;;
    *)
        echo_error "Unknown action: $ACTION"; usage
        ;;
esac
