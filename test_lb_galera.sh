#!/bin/bash

# Configuration
LB_HOST="127.0.0.1"
LB_PORT="3306"
USER="root"
PASS="rootpass"
ITERATIONS=40

# Create reports directory if it doesn't exist
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

# Report filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_MD="$REPORT_DIR/test_lb_galera_$TIMESTAMP.md"
REPORT_HTML="$REPORT_DIR/test_lb_galera_$TIMESTAMP.html"

echo "=========================================================="
echo "🚀 MariaDB Galera HAProxy Load Balancing Test"
echo "=========================================================="

# Function to write to report
write_report() {
    echo -e "$1" >> "$REPORT_MD"
}

# Initialize MD report
cat <<EOF > "$REPORT_MD"
# MariaDB Load Balancing Test Report
**Date:** $(date)
**Target:** $LB_HOST:$LB_PORT
**Iterations:** $ITERATIONS

EOF

# Data for reports
declare -A hosts_count
RAW_LOGS=""
TEST_RESULTS=""

echo "1. ⏳ Iterating through Load Balancer ($ITERATIONS connections)..."

for i in $(seq 1 $ITERATIONS); do
    # Use -sN for robust parsing of single values
    RESULT=$(mariadb -h "$LB_HOST" -P "$LB_PORT" -u "$USER" -p"$PASS" -sN -e "SELECT @@hostname, (SELECT VARIABLE_VALUE FROM information_schema.SESSION_STATUS WHERE VARIABLE_NAME='Ssl_cipher');" 2>/dev/null)
    if [ $? -eq 0 ]; then
        HOSTNAME=$(echo "$RESULT" | awk '{print $1}')
        SSL=$(echo "$RESULT" | awk '{print $2}')
        [ -z "$SSL" ] || [ "$SSL" == "NULL" ] && SSL="DISABLED"
        
        echo "   [Connection $i] -> $HOSTNAME (SSL: $SSL)"
        ((hosts_count["$HOSTNAME"]++))
        RAW_LOGS="$RAW_LOGS[Connection $i] -> $HOSTNAME (SSL: $SSL)\n"
    else
        echo "   [Connection $i] -> ❌ FAILED"
        RAW_LOGS="$RAW_LOGS[Connection $i] -> FAILED\n"
    fi
done

echo ""
echo "📊 Distribution Summary:"
echo "--------------------------------------------------------"
write_report "## Distribution Summary"
write_report "| Nom de l'hôte | Connexions | Pourcentage |"
write_report "| --- | --- | --- |"

DIST_DATA=""
for host in "${!hosts_count[@]}"; do
    count=${hosts_count[$host]}
    perc=$(echo "scale=2; $count*100/$ITERATIONS" | bc)
    printf "   %-15s : %d connections (%s%%)\n" "$host" "$count" "$perc"
    write_report "| $host | $count | $perc% |"
    DIST_DATA="$DIST_DATA{\"host\":\"$host\",\"count\":$count,\"perc\":$perc},"
done
echo "--------------------------------------------------------"

# Results Table logic
UNIQUE_HOSTS=${#hosts_count[@]}
LB_STATUS="FAIL"
LB_NATURE="Load Balancing Check"
LB_EXPECTED="Connections should be spread across 3 nodes"
LB_DETAILS="Connections hit $UNIQUE_HOSTS distinct hosts."

if [ "$UNIQUE_HOSTS" -ge 3 ]; then
    echo "✅ SUCCESS: Connections were balanced across $UNIQUE_HOSTS nodes."
    LB_STATUS="PASS"
else
    echo "⚠️  WARNING: Connections only hit $UNIQUE_HOSTS node(s). Check HAProxy status."
fi

write_report "\n## Résultats du Test"
write_report "| Nature du Test | Attendu | Statut | Résultat Réel / Détails |"
write_report "| --- | --- | --- | --- |"
write_report "| $LB_NATURE | $LB_EXPECTED | $LB_STATUS | $LB_DETAILS |"

TEST_RESULTS="{\"test\":\"$LB_NATURE\",\"nature\":\"$LB_NATURE\",\"expected\":\"$LB_EXPECTED\",\"status\":\"$LB_STATUS\",\"details\":\"$LB_DETAILS\"},"

# Generate HTML Report
cat <<'EOF' > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="fr" class="scroll-smooth">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MariaDB LB Test Report</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap');
        :root { --glass: rgba(15, 23, 42, 0.8); }
        body { font-family: 'Inter', sans-serif; background: #020617; color: #f8fafc; }
        .glass { background: var(--glass); backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.05); }
        .gradient-text { background: linear-gradient(135deg, #38bdf8 0%, #818cf8 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    </style>
</head>
<body class="min-h-screen pb-20">
    <div class="max-w-6xl mx-auto px-6 py-12">
        <header class="mb-16">
            <div class="flex items-center space-x-4 mb-4">
                <div class="w-12 h-12 bg-blue-500 rounded-2xl flex items-center justify-center shadow-lg shadow-blue-500/20">
                    <i class="fa-solid fa-network-wired text-xl text-white"></i>
                </div>
                <h1 class="text-4xl font-extrabold tracking-tight gradient-text">MariaDB LB Report</h1>
            </div>
            <div class="flex items-center text-slate-400 space-x-6">
                <span class="flex items-center"><i class="fa-regular fa-calendar-days mr-2"></i>REPLACE_DATE</span>
                <span class="flex items-center"><i class="fa-solid fa-server mr-2"></i>REPLACE_ITERATIONS iterations</span>
            </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-2 text-emerald-400">Statut Global</h3>
                <div class="text-xs text-slate-500 mb-6 uppercase tracking-widest font-bold">Health check</div>
                <div class="flex items-center space-x-4">
                    <div class="w-4 h-4 rounded-full REPLACE_LB_COLOR animate-pulse"></div>
                    <div class="text-2xl font-bold REPLACE_LB_TEXT_COLOR">REPLACE_LB_STATUS</div>
                </div>
            </div>
            <div class="glass p-8 rounded-3xl">
                <h3 class="text-xl font-bold mb-2 text-blue-400 italic">Distribution</h3>
                <div class="text-xs text-slate-500 mb-6 uppercase tracking-widest font-bold">Node hit count</div>
                <canvas id="distChart" class="max-h-48"></canvas>
            </div>
        </div>

        <div class="glass p-8 rounded-3xl mb-12">
            <h3 class="text-xl font-bold mb-6 text-blue-400 flex items-center italic">
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
                    <tbody id="test-results"></tbody>
                </table>
            </div>
        </div>

        <div class="glass p-8 rounded-3xl">
            <h3 class="text-xl font-bold mb-6 text-slate-400">Connection Logs</h3>
            <pre class="p-6 bg-black/40 rounded-2xl text-[10px] font-mono whitespace-pre overflow-y-auto h-96 text-slate-500 border border-white/5">REPLACE_RAW_LOGS</pre>
        </div>
    </div>

    <script>
        const distData = [REPLACE_DIST_DATA];
        const testResults = [REPLACE_TEST_RESULTS];

        new Chart(document.getElementById('distChart'), {
            type: 'doughnut',
            data: {
                labels: distData.map(d => d.host),
                datasets: [{
                    data: distData.map(d => d.count),
                    backgroundColor: ['#38bdf8', '#818cf8', '#34d399', '#fbbf24', '#f87171'],
                    borderWidth: 0,
                    hoverOffset: 20
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'right', labels: { color: '#94a3b8', font: { size: 11, family: 'Inter' }, padding: 20, usePointStyle: true } }
                },
                cutout: '75%'
            }
        });

        const resContainer = document.getElementById('test-results');
        testResults.forEach(item => {
            const row = document.createElement('tr');
            row.className = 'border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors cursor-default';
            row.innerHTML = `
                <td class="py-4 font-semibold text-slate-300 font-medium">${item.nature}</td>
                <td class="py-4 text-slate-400">${item.expected}</td>
                <td class="py-4">
                    <span class="px-2 py-1 rounded text-[10px] font-bold uppercase ${item.status === 'PASS' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : 'bg-red-500/10 text-red-500 border border-red-500/20'}">
                        ${item.status}
                    </span>
                </td>
                <td class="py-4 text-slate-400 text-xs font-mono font-medium">${item.details}</td>
            `;
            resContainer.appendChild(row);
        });
    </script>
</body>
</html>
EOF

# Replace placeholders in the HTML report
sed -i "s|REPLACE_DATE|$(date)|g" "$REPORT_HTML"
sed -i "s|REPLACE_ITERATIONS|$ITERATIONS|g" "$REPORT_HTML"
sed -i "s|REPLACE_LB_STATUS|$LB_STATUS|g" "$REPORT_HTML"
sed -i "s|REPLACE_LB_COLOR|$( [ "$LB_STATUS" == "PASS" ] && echo "bg-green-500" || echo "bg-red-500" )|g" "$REPORT_HTML"
sed -i "s|REPLACE_LB_TEXT_COLOR|$( [ "$LB_STATUS" == "PASS" ] && echo "text-green-400" || echo "text-red-400" )|g" "$REPORT_HTML"
sed -i "s|REPLACE_DIST_DATA|${DIST_DATA%?}|g" "$REPORT_HTML"
sed -i "s|REPLACE_TEST_RESULTS|${TEST_RESULTS%?}|g" "$REPORT_HTML"

# Safely escape backslashes and quotes for log inclusion
ESCAPED_LOGS=$(echo "$RAW_LOGS" | sed 's/\\/\\\\/g; s/"/\\"/g; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
python3 -c "import sys; c=open('$REPORT_HTML').read(); open('$REPORT_HTML','w').write(c.replace('REPLACE_RAW_LOGS', sys.argv[1]))" "$RAW_LOGS"

echo "=========================================================="
echo "🏁 Test Finished."
echo "Markdown Report: $REPORT_MD"
echo "HTML Report: $REPORT_HTML"
echo "=========================================================="
