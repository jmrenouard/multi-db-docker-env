#!/usr/bin/env bash
# Setup PostgreSQL 17 physical streaming replication (async or sync mode).
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
MODE="${1:-${PG_STREAM_MODE:-async}}"
PRI="pg_stream_primary"
STB="pg_stream_standby"

run_sql() {
    docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$PG_DB" -tAc "$2"
}

for node in "$PRI" "$STB"; do
    i=0
    until run_sql "$node" "SELECT 1;" >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge 45 ] && { echo "[FAIL] Timeout waiting for $node"; exit 1; }
        sleep 1
    done
    echo "[OK] $node ready"
done

pri_rec="$(run_sql "$PRI" "SELECT pg_is_in_recovery();")"
stb_rec="$(run_sql "$STB" "SELECT pg_is_in_recovery();")"
if [ "$pri_rec" != "f" ] || [ "$stb_rec" != "t" ]; then
    echo "[FAIL] Unexpected recovery roles: primary=$pri_rec standby=$stb_rec"
    exit 1
fi

i=0
until [ "$(run_sql "$PRI" "SELECT count(*) FROM pg_stat_replication WHERE application_name='pg_stream_standby' AND state='streaming';")" = "1" ]; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { echo "[FAIL] Streaming standby not connected"; exit 1; }
    sleep 1
done

if [ "$MODE" = "sync" ]; then
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_standby_names = 'pg_stream_standby';" >/dev/null
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_commit = 'on';" >/dev/null
    run_sql "$PRI" "SELECT pg_reload_conf();" >/dev/null
    want_state="sync"
else
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_standby_names = '';" >/dev/null
    run_sql "$PRI" "ALTER SYSTEM SET synchronous_commit = 'on';" >/dev/null
    run_sql "$PRI" "SELECT pg_reload_conf();" >/dev/null
    want_state="async"
fi

i=0
until [ "$(run_sql "$PRI" "SELECT sync_state FROM pg_stat_replication WHERE application_name='pg_stream_standby';")" = "$want_state" ]; do
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

slot_act="$(run_sql "$PRI" "SELECT active FROM pg_replication_slots WHERE slot_name='slot_stream_standby';")"
echo "[OK] pg-streaming ready (mode=$MODE sync_state=$want_state slot_active=$slot_act)"
