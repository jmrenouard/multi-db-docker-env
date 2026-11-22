#!/usr/bin/env bash
# Parameterized physical streaming replication setup for PostgreSQL 17 and 18.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib.sh"

MODE="${1:-${PG_STREAM_MODE:-async}}"
: "${PG_LABEL:?PG_LABEL required}"
: "${PRI:?PRI required}"
: "${STB:?STB required}"
: "${SLOT:?SLOT required}"
SHOW_IOM="${SHOW_IOM:-0}"

wait_pg_nodes 45 "$PRI" "$STB"

pri_rec="$(run_sql "$PRI" "SELECT pg_is_in_recovery();")"
stb_rec="$(run_sql "$STB" "SELECT pg_is_in_recovery();")"
if [ "$pri_rec" != "f" ] || [ "$stb_rec" != "t" ]; then
    echo "[FAIL] Unexpected recovery roles: primary=$pri_rec standby=$stb_rec"
    exit 1
fi

i=0
until [ "$(run_sql "$PRI" "SELECT count(*) FROM pg_stat_replication WHERE application_name='${STB}' AND state='streaming';")" = "1" ]; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { echo "[FAIL] ${PG_LABEL} standby not connected"; exit 1; }
    sleep 1
done

if [ "$MODE" = "sync" ]; then
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_standby_names = '${STB}';" >/dev/null
    want_state="sync"
else
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_standby_names = '';" >/dev/null
    want_state="async"
fi
run_sql "$PRI" "ALTER SYSTEM SET synchronous_commit = 'on';" >/dev/null
run_sql "$PRI" "SELECT pg_reload_conf();" >/dev/null

i=0
until [ "$(run_sql "$PRI" "SELECT sync_state FROM pg_stat_replication WHERE application_name='${STB}';")" = "$want_state" ]; do
    i=$((i + 1))
    [ "$i" -ge 20 ] && { echo "[FAIL] Expected sync_state=$want_state not reached"; exit 1; }
    sleep 1
done

run_sql "$PRI" "
    CREATE TABLE IF NOT EXISTS accounts (
        id BIGSERIAL PRIMARY KEY,
        owner TEXT NOT NULL,
        email TEXT UNIQUE,
        balance NUMERIC(14,2) NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );" >/dev/null

i=0
until [ "$(run_sql "$STB" "SELECT count(*) FROM information_schema.tables WHERE table_name='accounts';")" = "1" ]; do
    i=$((i + 1))
    [ "$i" -ge 20 ] && { echo "[FAIL] accounts table did not replicate to standby"; exit 1; }
    sleep 1
done

slot_act="$(run_sql "$PRI" "SELECT active FROM pg_replication_slots WHERE slot_name='${SLOT}';")"
extra=""
if [ "$SHOW_IOM" = "1" ]; then
    extra=" io_method=$(run_sql "$PRI" "SHOW io_method;")"
fi
echo "[OK] ${PG_LABEL} ready (mode=$MODE sync_state=$want_state slot_active=$slot_act${extra})"
