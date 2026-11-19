#!/usr/bin/env bash
# Setup bidirectional logical replication on two PostgreSQL 17 nodes.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"

run_sql() {
    docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$PG_DB" -tAc "$2"
}

for node in pg_birep_node1 pg_birep_node2; do
    i=0
    until run_sql "$node" "SELECT 1;" >/dev/null 2>&1; do
        i=$((i + 1)); [ "$i" -ge 30 ] && { echo "[FAIL] Timeout waiting for $node"; exit 1; }
        sleep 1
    done
    echo "[OK] $node ready"
done

for pair in "pg_birep_node1:1" "pg_birep_node2:2"; do
    node="${pair%%:*}"; start="${pair##*:}"
    run_sql "$node" "
        CREATE SEQUENCE IF NOT EXISTS accounts_id_seq INCREMENT BY 2 START WITH ${start};
        CREATE TABLE IF NOT EXISTS accounts (
            id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
            owner TEXT NOT NULL, email TEXT UNIQUE,
            balance NUMERIC(14,2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        ALTER SEQUENCE accounts_id_seq OWNED BY accounts.id;" >/dev/null
    if [ "$(run_sql "$node" "SELECT count(*) FROM pg_publication WHERE pubname='pub_birep';")" = "0" ]; then
        run_sql "$node" "CREATE PUBLICATION pub_birep FOR ALL TABLES;" >/dev/null
    fi
    echo "[OK] Schema & pub_birep ready on $node (step=2, start=$start)"
done

ESC_PASS="${PG_PASS//\'/\'\'}"
for spec in "pg_birep_node1:sub_from_node2:pg_birep_node2" "pg_birep_node2:sub_from_node1:pg_birep_node1"; do
    node="${spec%%:*}"; rest="${spec#*:}"; sub="${rest%%:*}"; peer="${rest##*:}"
    if [ "$(run_sql "$node" "SELECT count(*) FROM pg_subscription WHERE subname='${sub}';")" = "0" ]; then
        run_sql "$node" "CREATE SUBSCRIPTION ${sub} CONNECTION 'host=${peer} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}' PUBLICATION pub_birep WITH (origin = none, copy_data = true);" >/dev/null
    fi
    i=0
    until [ "$(run_sql "$node" "SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid WHERE s.subname='${sub}' AND r.srsubstate='r';")" = "1" ] 2>/dev/null; do
        i=$((i + 1)); [ "$i" -ge 30 ] && { echo "[FAIL] $sub on $node not ready"; exit 1; }
        sleep 1
    done
    echo "[OK] Subscription $sub streaming on $node"
done
