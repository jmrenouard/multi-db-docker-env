#!/bin/bash
set -euo pipefail

# Configuration Validation Script
REPORT_HTML="reports/config_report.html"
mkdir -p reports

echo "=========================================================="
echo "🔍 MariaDB Environment Configuration Validator"
echo "=========================================================="

RET=0
TEST_RESULTS_JS=""

add_result() {
    local test="$1"
    local expected="$2"
    local status="$3"
    local details="$4"
    # Escape for JS
    details=$(echo "$details" | sed "s/'/\\\'/g")
    TEST_RESULTS_JS+="{test: '$test', expected: '$expected', status: '$status', details: '$details'},"
}

check_file() {
    if [ -f "$1" ]; then
        echo "✅ File exists: $1"
        add_result "File Existence" "$1" "PASS" "File found correctly"
    else
        echo "❌ Missing file: $1"
        add_result "File Existence" "$1" "FAIL" "File is missing"
        RET=1
    fi
}

echo "1. Checking directory structure..."
for d in scripts conf tests documentation; do
    if [ -d "$d" ]; then
        echo "✅ Directory exists: $d"
        add_result "Directory Structure" "$d" "PASS" "Directory exists"
    else
        echo "❌ Missing directory: $d"
        add_result "Directory Structure" "$d" "FAIL" "Directory is missing"
        RET=1
    fi
done

echo -e "\n2. Checking Docker Compose files..."
for f in docker-compose.yml docker-compose-galera.yml docker-compose-repli.yml; do
    if [ -f "$f" ]; then
        echo "⏳ Validating syntax for $f..."
        if docker compose -f "$f" config > /dev/null 2>&1; then
            echo "✅ $f syntax is valid"
            add_result "Docker Compose" "$f" "PASS" "Syntax is valid"
        else
            echo "❌ $f syntax error"
            add_result "Docker Compose" "$f" "FAIL" "Syntax error detected"
            RET=1
        fi
    else
        echo "❌ Missing file: $f"
        add_result "Docker Compose" "$f" "FAIL" "File is missing"
        RET=1
    fi
done

echo -e "\n3. Checking configuration files in conf/..."
FILES_TO_CHECK=(
    "conf/custom_1.cnf" "conf/custom_2.cnf" "conf/custom_3.cnf"
    "conf/gcustom_1.cnf" "conf/gcustom_2.cnf" "conf/gcustom_3.cnf"
    "conf/haproxy-galera.cfg" "conf/haproxy-repli.cfg"
    "conf/init-permissions.sql" "conf/ssl.cnf" "conf/supervisord.conf"
)

for f in "${FILES_TO_CHECK[@]}"; do
    check_file "$f"
done

echo -e "\n4. Checking scripts in scripts/..."
SCRIPTS_TO_CHECK=(
    "scripts/backup_logical.sh" "scripts/backup_physical.sh"
    "scripts/gen_profiles.sh" "scripts/gen_ssl.sh"
    "scripts/restore_logical.sh" "scripts/restore_physical.sh"
    "scripts/setup_repli.sh" "scripts/start_mariadb.sh"
)

for s in "${SCRIPTS_TO_CHECK[@]}"; do
    if [ -x "$s" ]; then
        echo "✅ Script exists and is executable: $s"
        add_result "Script Permissions" "$s" "PASS" "Exists and executable"
    elif [ -f "$s" ]; then
        echo "⚠️  Script exists but is NOT executable: $s. Fixing..."
        chmod +x "$s"
        echo "✅ Fixed permissions for $s"
        add_result "Script Permissions" "$s" "PASS" "Fixed non-executable bit"
    else
        echo "❌ Missing script: $s"
        add_result "Script Permissions" "$s" "FAIL" "Script is missing"
        RET=1
    fi
done

echo -e "\n5. Checking Makefile targets consistency..."
# Ensure all referenced scripts in Makefile exist
awk -F' ' '/\.\/scripts\// {print $NF}' Makefile | sed 's|^./||' | sort -u | while read s; do
    s_clean=$(echo "$s" | sed 's/\$(.*)//g' | sed 's|/ \.\/|/|')
    if [[ "$s_clean" == scripts/* ]]; then
       if [ ! -f "$s_clean" ]; then
           s_base=$(echo "$s_clean" | cut -d' ' -f1)
           if [ ! -f "$s_base" ]; then
               echo "❌ Makefile references missing script: $s_base"
               add_result "Makefile Consistency" "$s_base" "FAIL" "Referenced script missing"
           fi
       else 
           add_result "Makefile Consistency" "$s_clean" "PASS" "Script referenced exists"
       fi
    fi
done

# Generate HTML Report
cat <<EOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Config Validation Report</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background: #0f172a; color: #f1f5f9; }
        .glass { background: rgba(255, 255, 255, 0.03); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.05); }
    </style>
</head>
<body class="p-8">
    <div class="max-w-5xl mx-auto">
        <header class="mb-12">
            <h1 class="text-4xl font-black mb-2 bg-gradient-to-r from-blue-400 to-emerald-400 bg-clip-text text-transparent">Config Validation</h1>
            <p class="text-slate-400">Environment & Orchestration Health Check • $(date)</p>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
            <div class="glass p-6 rounded-2xl">
                <div class="text-slate-500 text-xs uppercase font-bold mb-1">Status</div>
                <div class="text-2xl font-bold $( [ $RET -eq 0 ] && echo "text-emerald-400" || echo "text-rose-400" )">
                    $( [ $RET -eq 0 ] && echo "ALL PASSED" || echo "FAILED" )
                </div>
            </div>
            <div class="glass p-6 rounded-2xl">
                <div class="text-slate-500 text-xs uppercase font-bold mb-1">Total Checks</div>
                <div id="check-count" class="text-2xl font-bold text-white">0</div>
            </div>
        </div>

        <div class="glass rounded-3xl overflow-hidden">
            <table class="w-full text-left">
                <thead>
                    <tr class="bg-white/5 text-[10px] uppercase tracking-widest font-bold text-slate-500">
                        <th class="px-6 py-4">Category</th>
                        <th class="px-6 py-4">Target</th>
                        <th class="px-6 py-4">Status</th>
                        <th class="px-6 py-4">Details</th>
                    </tr>
                </thead>
                <tbody id="results-body"></tbody>
            </table>
        </div>
    </div>

    <script>
        const results = [${TEST_RESULTS_JS%?}];
        document.getElementById('check-count').innerText = results.length;
        const body = document.getElementById('results-body');
        results.forEach(res => {
            const tr = document.createElement('tr');
            tr.className = "border-t border-white/5 hover:bg-white/[0.02] transition-colors";
            tr.innerHTML = \`
                <td class="px-6 py-4 font-medium text-slate-300">\${res.test}</td>
                <td class="px-6 py-4 text-xs font-mono text-slate-400">\${res.expected}</td>
                <td class="px-6 py-4">
                    <span class="px-2 py-1 rounded text-[10px] font-bold \${res.status === 'PASS' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}">
                        \${res.status}
                    </span>
                </td>
                <td class="px-6 py-4 text-xs text-slate-500">\${res.details}</td>
            \`;
            body.appendChild(tr);
        });
    </script>
</body>
</html>
EOF

echo -e "\n=========================================================="
if [ $RET -eq 0 ]; then
    echo "🎉 All configuration tests passed!"
else
    echo "❌ Some configuration tests failed. Please check the logs above."
fi
echo "Report: $REPORT_HTML"
echo "=========================================================="

exit $RET
