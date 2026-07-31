#!/usr/bin/env bash
# test_secure_password.sh — Security regression tests for issue #2
set -uo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ok()   { echo "  [PASS] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo ""
echo "Security Test: No Insecure -p<password> CLI Args"
echo "================================================="

check_no_pattern() {
    local file="$1" pattern="$2" desc="$3"
    if [[ ! -f "$REPO_ROOT/$file" ]]; then echo "  [SKIP] $file not found"; return; fi
    if grep -qP "$pattern" "$REPO_ROOT/$file" 2>/dev/null; then
        fail "$desc — insecure pattern in $file:"
        grep -nP "$pattern" "$REPO_ROOT/$file" | sed 's/^/       /'
    else
        ok "$desc — $file clean"
    fi
}

check_uses() {
    local file="$1" pattern="$2" desc="$3"
    if [[ ! -f "$REPO_ROOT/$file" ]]; then echo "  [SKIP] $file not found"; return; fi
    if grep -q "$pattern" "$REPO_ROOT/$file" 2>/dev/null; then
        ok "$desc — uses $pattern"
    else
        fail "$desc — does NOT use $pattern"
    fi
}

echo ""
echo "-- tests/test_lab.py"
check_no_pattern "tests/test_lab.py" 'f\"-p\{self\.db_root_password\}\"' "No inline -p<password>"
check_uses       "tests/test_lab.py" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/setup_repli.sh"
check_no_pattern "scripts/setup_repli.sh" '\-p\$PASS' "No -p\$PASS in mariadb"
check_uses       "scripts/setup_repli.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/run_mysqltuner.sh"
check_no_pattern "scripts/run_mysqltuner.sh" 'mysqladmin.*-p"' "No -p password in mysqladmin"
check_uses       "scripts/run_mysqltuner.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/start_mariadb.sh"
check_no_pattern "scripts/start_mariadb.sh" ':-p\"\$MARIADB_ROOT' "No conditional -p arg"
check_uses       "scripts/start_mariadb.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "================================================="
echo "Results: $PASS passed / $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All security checks passed!" && exit 0
exit 1
