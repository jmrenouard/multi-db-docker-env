#!/bin/bash
# tests/lib/common.sh
# Shared shell test library for multi-db-docker-env functional test suites

set -euo pipefail

# Global Counters & Variables
PASS=0
FAIL=0
TEST_RESULTS_JSON=""
REPORT_MD=""
REPORT_HTML=""

init_report() {
    local suite_name="$1"
    local suite_title="${2:-$suite_name Test Report}"
    local report_dir="./reports"

    mkdir -p "$report_dir"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    REPORT_MD="$report_dir/${suite_name}_${timestamp}.md"
    REPORT_HTML="$report_dir/${suite_name}_${timestamp}.html"

    cat <<EOF > "$REPORT_MD"
# $suite_title
**Date:** $(date)

EOF
}

write_report() {
    if [ -n "$REPORT_MD" ]; then
        echo -e "$1" >> "$REPORT_MD"
    fi
}

assert_pass() {
    local name="$1"
    local details="${2:-Verified}"
    PASS=$((PASS + 1))
    echo "✅ $name: SUCCESS ($details)"
    write_report "- ✅ **$name**: SUCCESS ($details)"
}

assert_fail() {
    local name="$1"
    local details="${2:-Failed}"
    FAIL=$((FAIL + 1))
    echo "❌ $name: FAILED ($details)"
    write_report "- ❌ **$name**: FAILED ($details)"
}

init_ssl_flags() {
    local ca_path="${1:-./ssl/ca-cert.pem}"
    if [ -f "$ca_path" ]; then
        SSL_FLAGS="--ssl-ca=$ca_path"
    else
        SSL_FLAGS=""
    fi
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local name="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        assert_pass "$name" "Found '$needle'"
    else
        assert_fail "$name" "Expected '$needle' in output"
    fi
}

wait_for_innodb_gr_online() {
    local exec_cmd="$1"
    local expected_nodes="${2:-3}"
    local max_wait="${3:-60}"
    local elapsed=0

    echo "⏳ Waiting for $expected_nodes Group Replication nodes to reach ONLINE state (max ${max_wait}s)..."
    while [ "$elapsed" -lt "$max_wait" ]; do
        local count
        count=$(eval "$exec_cmd" 2>/dev/null || echo "0")
        count=$(echo "$count" | tr -d '[:space:]')
        if [ "$count" -ge "$expected_nodes" ] 2>/dev/null; then
            echo "   ✅ All $expected_nodes nodes are ONLINE."
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    echo "❌ ERROR: Group Replication ONLINE count ($count) did not reach expected $expected_nodes within ${max_wait}s" >&2
    return 1
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local name="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$name" "Expected '$expected', got '$actual'"
    else
        assert_fail "$name" "Expected '$expected', got '$actual'"
    fi
}

assert_greater_than() {
    local min_val="$1"
    local actual_val="$2"
    local name="$3"
    if [ "$actual_val" -gt "$min_val" ] 2>/dev/null; then
        assert_pass "$name" "Got $actual_val (min threshold: $min_val)"
    else
        assert_fail "$name" "Got $actual_val (min threshold: $min_val)"
    fi
}

print_summary() {
    local total=$((PASS + FAIL))
    if [ -n "$REPORT_MD" ] && [ -n "$REPORT_HTML" ] && [ -f "$REPORT_MD" ]; then
        cat <<EOF > "$REPORT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Test Report</title>
    <style>
        body { font-family: system-ui, sans-serif; background-color: #0f172a; color: #f1f5f9; padding: 2rem; }
        .pass { color: #4ade80; font-weight: bold; }
        .fail { color: #f87171; font-weight: bold; }
        pre { background: #1e293b; padding: 1rem; border-radius: 0.5rem; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>Test Report Summary</h1>
    <p>Passed: <span class="pass">$PASS</span> / $total | Failed: <span class="fail">$FAIL</span> / $total</p>
    <hr style="border-color: #334155; margin: 1rem 0;">
    <pre>$(cat "$REPORT_MD")</pre>
</body>
</html>
EOF
    fi

    echo ""
    echo "=========================================================="
    echo "🏁 Test Suite Summary"
    echo "   Passed: $PASS / $total"
    echo "   Failed: $FAIL / $total"
    if [ -n "$REPORT_MD" ]; then
        echo "   Markdown Report: $REPORT_MD"
    fi
    if [ -n "$REPORT_HTML" ]; then
        echo "   HTML Report:     $REPORT_HTML"
    fi
    echo "=========================================================="

    if [ "$FAIL" -gt 0 ]; then
        return 1
    fi
    return 0
}
