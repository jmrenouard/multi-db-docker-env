#!/usr/bin/env bash
# Parameterized uni-directional logical replication setup for PostgreSQL 17 and 18.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib.sh"

: "${PUB:?PUB required}"
: "${SUB:?SUB required}"
: "${PUB_NAME:?PUB_NAME required}"
: "${SUB_NAME:?SUB_NAME required}"
SHOW_SUBSTREAM="${SHOW_SUBSTREAM:-0}"

wait_pg_nodes 30 "$PUB" "$SUB"

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

if [ "$(run_sql "$PUB" "SELECT count(*) FROM pg_publication WHERE pubname='${PUB_NAME}';")" = "0" ]; then
    run_sql "$PUB" "CREATE PUBLICATION ${PUB_NAME} FOR ALL TABLES;" >/dev/null
fi
echo "[OK] Publication ${PUB_NAME} ready on $PUB"

ESC_PASS="$(esc_conn_val "$PG_PASS")"
if [ "$(run_sql "$SUB" "SELECT count(*) FROM pg_subscription WHERE subname='${SUB_NAME}';")" = "0" ]; then
    run_sql "$SUB" "CREATE SUBSCRIPTION ${SUB_NAME} CONNECTION 'host=${PUB} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}' PUBLICATION ${PUB_NAME} WITH (copy_data = true);" >/dev/null
fi

i=0
until [ "$(run_sql "$SUB" "SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid WHERE s.subname='${SUB_NAME}' AND r.srsubstate='r';")" = "1" ] 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { echo "[FAIL] ${SUB_NAME} not ready on $SUB"; exit 1; }
    sleep 1
done

extra=""
if [ "$SHOW_SUBSTREAM" = "1" ]; then
    extra=" (substream=$(run_sql "$SUB" "SELECT substream FROM pg_subscription WHERE subname='${SUB_NAME}';"))"
fi
echo "[OK] Subscription ${SUB_NAME} streaming on ${SUB}${extra}"
