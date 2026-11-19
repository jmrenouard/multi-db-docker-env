#!/usr/bin/env bash
# Setup PostgreSQL 17 native uni-directional logical replication (pub -> sub).
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
PUB="pg_logical_pub"
SUB="pg_logical_sub"

run_sql() {
    docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$PG_DB" -tAc "$2"
}

for node in "$PUB" "$SUB"; do
    i=0
    until run_sql "$node" "SELECT 1;" >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge 30 ] && { echo "[FAIL] Timeout waiting for $node"; exit 1; }
        sleep 1
    done
    echo "[OK] $node ready"
done

for node in "$PUB" "$SUB"; do
    run_sql "$node" "
        CREATE TABLE IF NOT EXISTS accounts (
            id BIGSERIAL PRIMARY KEY,
            owner TEXT NOT NULL,
            email TEXT UNIQUE,
            balance NUMERIC(14,2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );" >/dev/null
    echo "[OK] Schema accounts ready on $node"
done

if [ "$(run_sql "$PUB" "SELECT count(*) FROM pg_publication WHERE pubname='pub_logical';")" = "0" ]; then
    run_sql "$PUB" "CREATE PUBLICATION pub_logical FOR ALL TABLES;" >/dev/null
fi
echo "[OK] Publication pub_logical ready on $PUB"

ESC_PASS="${PG_PASS//\'/\'\'}"
if [ "$(run_sql "$SUB" "SELECT count(*) FROM pg_subscription WHERE subname='sub_logical';")" = "0" ]; then
    run_sql "$SUB" "CREATE SUBSCRIPTION sub_logical CONNECTION 'host=${PUB} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}' PUBLICATION pub_logical WITH (copy_data = true);" >/dev/null
fi

i=0
until [ "$(run_sql "$SUB" "SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid WHERE s.subname='sub_logical' AND r.srsubstate='r';")" = "1" ] 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { echo "[FAIL] sub_logical not ready on $SUB"; exit 1; }
    sleep 1
done
echo "[OK] Subscription sub_logical streaming on $SUB"
