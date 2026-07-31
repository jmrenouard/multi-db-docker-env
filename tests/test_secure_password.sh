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
echo "-- Makefile"
check_no_pattern "Makefile" '\-p"(\$\(DB_ROOT_PASSWORD\)|\$\$\{DB_ROOT_PASSWORD)' "No inline -p in Makefile"
check_uses       "Makefile" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- conf/innodb-cluster/setup_cluster.sh"
check_no_pattern "conf/innodb-cluster/setup_cluster.sh" '\-p"\$DB_PASS"' "No inline -p in setup_cluster.sh"
check_uses       "conf/innodb-cluster/setup_cluster.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/backup_logical.sh"
check_no_pattern "scripts/backup_logical.sh" '\-p\$DB_PASS' "No inline -p in backup_logical.sh"
check_uses       "scripts/backup_logical.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/restore_logical.sh"
check_no_pattern "scripts/restore_logical.sh" '\-p\$DB_PASS' "No inline -p in restore_logical.sh"
check_uses       "scripts/restore_logical.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- scripts/gen_profiles.sh"
check_no_pattern "scripts/gen_profiles.sh" '\-p\$PASS' "No inline -p in gen_profiles.sh"
check_uses       "scripts/gen_profiles.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_galera.sh"
check_no_pattern "tests/test_galera.sh" '\-p\$PASS' "No inline -p in test_galera.sh"
check_uses       "tests/test_galera.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_haproxy_galera.sh"
check_no_pattern "tests/test_haproxy_galera.sh" '\-p\$PASS' "No inline -p in test_haproxy_galera.sh"
check_uses       "tests/test_haproxy_galera.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_innodb_cluster.sh"
check_no_pattern "tests/test_innodb_cluster.sh" '\-p"\$DB_PASS"' "No inline -p in test_innodb_cluster.sh"
check_uses       "tests/test_innodb_cluster.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_lb_galera.sh"
check_no_pattern "tests/test_lb_galera.sh" '\-p"\$PASS"' "No inline -p in test_lb_galera.sh"
check_uses       "tests/test_lb_galera.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_perf_galera.sh"
check_no_pattern "tests/test_perf_galera.sh" '\-p\$DB_PASS' "No inline -p in test_perf_galera.sh"
check_uses       "tests/test_perf_galera.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_perf_repli.sh"
check_no_pattern "tests/test_perf_repli.sh" '\-p\$DB_PASS' "No inline -p in test_perf_repli.sh"
check_uses       "tests/test_perf_repli.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "-- tests/test_repli.sh"
check_no_pattern "tests/test_repli.sh" '\-p\$PASS' "No inline -p in test_repli.sh"
check_uses       "tests/test_repli.sh" "MYSQL_PWD" "Uses MYSQL_PWD"

echo ""
echo "================================================="
echo "Results: $PASS passed / $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All security checks passed!" && exit 0
exit 1
