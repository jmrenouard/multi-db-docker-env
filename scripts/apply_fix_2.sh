#!/usr/bin/env bash
# apply_fix_2.sh — Fix insecure -p<password> CLI args (issue #2)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "[fix2] Patching tests/test_lab.py..."
python3 /tmp/patch_test_lab.py

echo "[fix2] Patching scripts/setup_repli.sh..."
sed -i \
    -e 's|mariadb -h 127\.0\.0\.1 -P \$port -u\$USER -p\$PASS |MYSQL_PWD="$PASS" mariadb -h 127.0.0.1 -P $port -u$USER |g' \
    -e 's|mariadb -h 127\.0\.0\.1 -P \$port -u\$USER -p\$PASS$|MYSQL_PWD="$PASS" mariadb -h 127.0.0.1 -P $port -u$USER|g' \
    -e 's|mariadb-dump -h 127\.0\.0\.1 -P \$MASTER_PORT -u\$USER -p\$PASS|MYSQL_PWD="$PASS" mariadb-dump -h 127.0.0.1 -P $MASTER_PORT -u$USER|g' \
    scripts/setup_repli.sh && echo "  Patched setup_repli.sh"

echo "[fix2] Patching scripts/run_mysqltuner.sh..."
sed -i \
    -e 's|mysqladmin -h 127\.0\.0\.1 -P "\$p" -u "\$DB_USER" -p"\$DB_PASS"|MYSQL_PWD="$DB_PASS" mysqladmin -h 127.0.0.1 -P "$p" -u "$DB_USER"|g' \
    scripts/run_mysqltuner.sh && echo "  Patched run_mysqltuner.sh"

echo "[fix2] Patching scripts/start_mariadb.sh..."
sed -i \
    -e 's|mariadb-admin --socket="$SOCKET" -u root ${MARIADB_ROOT_PASSWORD:+-p"$MARIADB_ROOT_PASSWORD"}|MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-}" mariadb-admin --socket="$SOCKET" -u root|g' \
    scripts/start_mariadb.sh && echo "  Patched start_mariadb.sh"

echo "[fix2] All patches applied."
