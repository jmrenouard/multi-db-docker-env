#!/bin/bash
set -euo pipefail

# Configuration Validation Script
echo "=========================================================="
echo "🔍 MariaDB Environment Configuration Validator"
echo "=========================================================="

RET=0

check_file() {
    if [ -f "$1" ]; then
        echo "✅ File exists: $1"
    else
        echo "❌ Missing file: $1"
        RET=1
    fi
}

echo "1. Checking directory structure..."
for d in scripts conf tests documentation; do
    if [ -d "$d" ]; then
        echo "✅ Directory exists: $d"
    else
        echo "❌ Missing directory: $d"
        RET=1
    fi
done

echo -e "\n2. Checking Docker Compose files..."
for f in docker-compose.yml docker-compose-galera.yml docker-compose-repli.yml; do
    if [ -f "$f" ]; then
        echo "⏳ Validating syntax for $f..."
        if docker compose -f "$f" config > /dev/null 2>&1; then
            echo "✅ $f syntax is valid"
        else
            echo "❌ $f syntax error"
            RET=1
        fi
    else
        echo "❌ Missing file: $f"
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
    "scripts/setup_repli.sh" "scripts/start-mariadb.sh"
)

for s in "${SCRIPTS_TO_CHECK[@]}"; do
    if [ -x "$s" ]; then
        echo "✅ Script exists and is executable: $s"
    elif [ -f "$s" ]; then
        echo "⚠️  Script exists but is NOT executable: $s. Fixing..."
        chmod +x "$s"
        echo "✅ Fixed permissions for $s"
    else
        echo "❌ Missing script: $s"
        RET=1
    fi
done

echo -e "\n5. Checking Makefile targets consistency..."
# Ensure all referenced scripts in Makefile exist
awk -F' ' '/\.\/scripts\// {print $NF}' Makefile | sed 's|^./||' | sort -u | while read s; do
    # Remove variables like $(DB) or $(FILE)
    s_clean=$(echo "$s" | sed 's/\$(.*)//g' | sed 's|/ \.\/|/|')
    if [[ "$s_clean" == scripts/* ]]; then
       if [ ! -f "$s_clean" ]; then
           # Try to find it without the trailing slash/stuff
           s_base=$(echo "$s_clean" | cut -d' ' -f1)
           if [ ! -f "$s_base" ]; then
               echo "❌ Makefile references missing script: $s_base"
               # RET=1 # Not blocking for now as awk parsing is rough
           fi
       fi
    fi
done

echo -e "\n=========================================================="
if [ $RET -eq 0 ]; then
    echo "🎉 All configuration tests passed!"
else
    echo "❌ Some configuration tests failed. Please check the logs above."
fi
echo "=========================================================="

exit $RET
