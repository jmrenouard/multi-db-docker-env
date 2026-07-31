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
