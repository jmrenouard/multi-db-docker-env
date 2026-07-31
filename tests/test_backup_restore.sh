#!/bin/bash
# tests/test_backup_restore.sh
# Functional test suite for Backup & Restore verification across clusters

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    PASS=0
    FAIL=0
    assert_pass() { PASS=$((PASS + 1)); echo "✅ $1: $2"; }
    assert_fail() { FAIL=$((FAIL + 1)); echo "❌ $1: $2"; }
    print_summary() { echo "Passed: $PASS | Failed: $FAIL"; [ "$FAIL" -eq 0 ]; }
    init_report() { :; }
fi

init_report "test_backup_restore" "Backup & Restore Verification Report"

echo "=========================================================="
echo "💾 Backup & Restore Automated Verification Suite"
echo "=========================================================="

# 1. Script Availability Checks
echo ""
echo "1. 📜 Checking Backup & Restore Script Existence..."
SCRIPTS=(
    "scripts/backup_logical.sh"
    "scripts/backup_physical.sh"
    "scripts/restore_logical.sh"
    "scripts/restore_physical.sh"
)

for s in "${SCRIPTS[@]}"; do
    if [ -f "$s" ] && [ -x "$s" ]; then
        assert_pass "Script Check" "Found executable $s"
    else
        assert_fail "Script Check" "Missing or non-executable $s"
    fi
done

# 2. Script Usage Output Verification
echo ""
echo "2. ⚙️  Verifying Script Usage / CLI Interface..."
for s in "${SCRIPTS[@]}"; do
    OUTPUT=$(bash "$s" 2>&1 || true)
    if echo "$OUTPUT" | grep -qi "usage"; then
        assert_pass "Usage Check" "$s outputs usage instructions"
    else
        assert_fail "Usage Check" "$s missing usage instructions"
    fi
done

# 3. Active Cluster Backup Verification (Galera / Repli if running)
echo ""
echo "3. 📦 Active Cluster Backup Verification..."

if docker ps --format '{{.Names}}' | grep -q "mariadb-g1"; then
    echo ">> Testing Galera Logical Backup..."
    if bash scripts/backup_logical.sh galera testdb &>/dev/null; then
        assert_pass "Galera Backup" "Logical backup created successfully"
    else
        assert_fail "Galera Backup" "Logical backup failed"
    fi
else
    echo "ℹ️ Galera cluster not running. Skipping live backup test."
fi

print_summary
