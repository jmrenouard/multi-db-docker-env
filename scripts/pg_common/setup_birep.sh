#!/usr/bin/env bash
# Parameterized bidirectional logical replication setup for PostgreSQL 17 and 18.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib.sh"

: "${N1:?N1 required}"
: "${N2:?N2 required}"
: "${PUB_NAME:?PUB_NAME required}"

wait_pg_nodes 30 "$N1" "$N2"

for pair in "${N1}:1" "${N2}:2"; do
    node="${pair%%:*}"
    start="${pair##*:}"
    run_sql "$node" "
        CREATE SEQUENCE IF NOT EXISTS accounts_id_seq INCREMENT BY 2 START WITH ${start};
        CREATE TABLE IF NOT EXISTS accounts (
            id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
            owner TEXT NOT NULL,
            email TEXT UNIQUE,
            balance NUMERIC(14,2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        ALTER SEQUENCE accounts_id_seq OWNED BY accounts.id;" >/dev/null
    if [ "$(run_sql "$node" "SELECT count(*) FROM pg_publication WHERE pubname='${PUB_NAME}';")" = "0" ]; then
        run_sql "$node" "CREATE PUBLICATION ${PUB_NAME} FOR ALL TABLES;" >/dev/null
    fi
    echo "[OK] Schema & ${PUB_NAME} ready on $node (step=2, start=$start)"
done

ESC_PASS="$(esc_conn_val "$PG_PASS")"
for spec in "${N1}:sub_from_node2:${N2}" "${N2}:sub_from_node1:${N1}"; do
    node="${spec%%:*}"
    rest="${spec#*:}"
    sub="${rest%%:*}"
    peer="${rest##*:}"
    if [ "$(run_sql "$node" "SELECT count(*) FROM pg_subscription WHERE subname='${sub}';")" = "0" ]; then
        run_sql "$node" "CREATE SUBSCRIPTION ${sub} CONNECTION 'host=${peer} port=5432 dbname=${PG_DB} user=${PG_USER} password=${ESC_PASS}' PUBLICATION ${PUB_NAME} WITH (origin = none, copy_data = true);" >/dev/null
    fi
    i=0
    until [ "$(run_sql "$node" "SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid WHERE s.subname='${sub}' AND r.srsubstate='r';")" = "1" ] 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -ge 30 ] && { echo "[FAIL] $sub on $node not ready"; exit 1; }
        sleep 1
    done
    echo "[OK] Subscription $sub streaming on $node"
done
