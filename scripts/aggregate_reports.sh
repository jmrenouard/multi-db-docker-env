#!/bin/bash
# scripts/aggregate_reports.sh
# Aggregates individual cluster test reports into a consolidated HTML report

set -euo pipefail

REPORT_DIR="./reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_HTML="$REPORT_DIR/test_all_aggregated_$TIMESTAMP.html"
LATEST_HTML="$REPORT_DIR/latest_aggregated_report.html"

echo "=========================================================="
echo "📊 Aggregating All Cluster Test Reports..."
echo "=========================================================="

# Find all latest html reports per test suite
REPORTS=$(find "$REPORT_DIR" -maxdepth 1 -name "*.html" ! -name "*aggregated*" | sort)

TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_SUMMARY_ROWS=""

if [ ! -d "$REPORT_DIR" ]; then
    echo "⚠️  No test reports directory found at $REPORT_DIR/"
else
    while IFS= read -r r; do
        [ -f "$r" ] || continue
        BASENAME=$(basename "$r")
        # Extract title or filename
        TITLE=$(grep -oP '<title>\K[^<]+' "$r" 2>/dev/null || echo "$BASENAME")
        
        # Count passes and fails using word matches to avoid substrings (e.g. "password")
        PASS_CNT=$( (grep -oiw "pass" "$r" 2>/dev/null || true) | wc -l | tr -d '[:space:]')
        FAIL_CNT=$( (grep -oiw "fail" "$r" 2>/dev/null || true) | wc -l | tr -d '[:space:]')
        
        TOTAL_PASS=$((TOTAL_PASS + PASS_CNT))
        TOTAL_FAIL=$((TOTAL_FAIL + FAIL_CNT))

        SUITE_SUMMARY_ROWS+="<tr class=\"border-b border-slate-700/50 hover:bg-slate-800/30\"><td class=\"py-3 px-4 font-semibold text-slate-200\">$TITLE</td><td class=\"py-3 px-4 text-xs font-mono text-slate-400\">$BASENAME</td><td class=\"py-3 px-4 text-green-400 font-bold\">$PASS_CNT</td><td class=\"py-3 px-4 text-red-400 font-bold\">$FAIL_CNT</td><td class=\"py-3 px-4\"><a href=\"$BASENAME\" target=\"_blank\" class=\"text-cyan-400 hover:underline text-xs\">View Report &rarr;</a></td></tr>"
    done < <(find "$REPORT_DIR" -maxdepth 1 -name "*.html" ! -name "*aggregated*" | sort)
fi

cat <<EOF > "$OUT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Consolidated Multi-DB Test Report</title>
    <script src="https://cdn.tailwindcss.com"></script>
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
                <h1 class="text-4xl font-bold bg-gradient-to-r from-cyan-400 to-indigo-500 bg-clip-text text-transparent italic">
                    📊 Consolidated Multi-DB Test Report
                </h1>
                <p class="text-slate-400 mt-2 font-light italic">Aggregated verification summary across all database clusters</p>
            </div>
            <div class="text-right">
                <span class="text-slate-500 text-xs font-mono">Generated: $(date)</span>
            </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="glass p-6 rounded-2xl text-center border-l-4 border-green-500">
                <div class="text-slate-400 text-sm font-semibold uppercase">Total Assertions Passed</div>
                <div class="text-4xl font-bold text-green-400 mt-2">$TOTAL_PASS</div>
            </div>
            <div class="glass p-6 rounded-2xl text-center border-l-4 border-red-500">
                <div class="text-slate-400 text-sm font-semibold uppercase">Total Assertions Failed</div>
                <div class="text-4xl font-bold text-red-400 mt-2">$TOTAL_FAIL</div>
            </div>
        </div>

        <div class="glass p-8 rounded-3xl">
            <h3 class="text-xl font-bold mb-6 text-indigo-400">Cluster Test Suite Reports</h3>
            <div class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="text-slate-500 uppercase text-[10px] font-bold border-b border-slate-700/50">
                            <th class="pb-3 px-4">Test Suite</th>
                            <th class="pb-3 px-4">Report File</th>
                            <th class="pb-3 px-4">Pass</th>
                            <th class="pb-3 px-4">Fail</th>
                            <th class="pb-3 px-4">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${SUITE_SUMMARY_ROWS:-<tr><td colspan="5" class="py-4 text-center text-slate-500">No individual reports found. Run test suites first!</td></tr>}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</body>
</html>
EOF

cp -f "$OUT_HTML" "$LATEST_HTML"

echo "✅ Consolidated report created:"
echo "   Aggregated Report: $OUT_HTML"
echo "   Latest Report:     $LATEST_HTML"
echo "=========================================================="
