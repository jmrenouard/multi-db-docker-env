#!/usr/bin/env bash
# Shared PostgreSQL lab setup helpers for PG 17 and PG 18 scripts.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"

run_sql() {
    docker exec -e PGPASSWORD="$PG_PASS" "$1" psql -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$PG_DB" -tAc "$2"
}

wait_pg_nodes() {
    local max_wait="$1"
    shift
    local node i
    for node in "$@"; do
        i=0
        until run_sql "$node" "SELECT 1;" >/dev/null 2>&1; do
            i=$((i + 1))
            [ "$i" -ge "$max_wait" ] && { echo "[FAIL] Timeout waiting for $node"; exit 1; }
            sleep 1
        done
        echo "[OK] $node ready"
    done
}

esc_conn_val() {
    local v="$1"
    v="${v//\\/\\\\}"
    v="${v//\'/\\\'}"
    v="${v// /\\ }"
    printf '%s' "${v//\'/\'\'}"
}
