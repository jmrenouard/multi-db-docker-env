#!/usr/bin/env bash
# Verify 3-node YT Cluster 1.21.3 (PostgreSQL 18 + yt_cluster/ytserv) readiness and config.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-labdb}"
PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
NODES=(yt1 yt2 yt3)
TIMEOUT_SEC="${YT_WAIT_TIMEOUT:-90}"

q() {
  local node="$1" db="$2" sql="$3"
  docker exec -e PGPASSWORD="$PG_PASS" "$node" \
    psql -X -q -v ON_ERROR_STOP=1 -U "$PG_USER" -d "$db" -tAc "$sql"
}

echo "[yt-setup] Waiting for 3-node YT Cluster (${NODES[*]}) to elect a leader..."
deadline=$(( $(date +%s) + TIMEOUT_SEC ))
leader_ok=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  ready=0
  leaders=0
  for n in "${NODES[@]}"; do
    if docker exec "$n" yt-health >/dev/null 2>&1; then
      info="$(q "$n" postgres "SELECT yt_info('o')::text;" 2>/dev/null || true)"
      if echo "$info" | grep -q "Leader"; then
        ready=$((ready + 1))
        if echo "$info" | grep -q '"Leader"' || echo "$info" | grep -q ', Leader"'; then
          leaders=$((leaders + 1))
        fi
      fi
    fi
  done
  if [ "$ready" -eq 3 ] && [ "$leaders" -ge 1 ]; then
    leader_ok=1
    break
  fi
  sleep 2
done

if [ "$leader_ok" -ne 1 ]; then
  echo "[yt-setup] ERROR: 3-node YT Cluster did not elect a leader within ${TIMEOUT_SEC}s." >&2
  for n in "${NODES[@]}"; do
    echo "--- $n yt_info('o') ---" >&2
    q "$n" postgres "SELECT yt_info('o')::text;" 2>&1 || true
  done
  exit 1
fi

echo "[yt-setup] Cluster leader election verified:"
for n in "${NODES[@]}"; do
  info="$(q "$n" postgres "SELECT yt_info('o')::text;")"
  ext_pg="$(q "$n" postgres "SELECT extversion FROM pg_extension WHERE extname='yt_cluster';")"
  ext_db="$(q "$n" "$PG_DB" "SELECT extversion FROM pg_extension WHERE extname='yt_cluster';")"
  mpt="$(q "$n" "$PG_DB" "SHOW max_prepared_transactions;")"
  ac="$(q "$n" "$PG_DB" "SHOW yt_cluster.auto_complete;")"
  echo "  $n: yt_info(o)=$info | ext(postgres)=$ext_pg ext($PG_DB)=$ext_db | max_prepared=$mpt auto_complete=$ac"
  if [ -z "$ext_pg" ] || [ -z "$ext_db" ]; then
    echo "[yt-setup] ERROR: yt_cluster extension missing on $n." >&2
    exit 1
  fi
  if [ "$mpt" -lt 100 ]; then
    echo "[yt-setup] ERROR: max_prepared_transactions=$mpt < 100 on $n." >&2
    exit 1
  fi
done

ver="$(q yt1 "$PG_DB" "SELECT version();")"
iom="$(q yt1 "$PG_DB" "SHOW io_method;")"
chk="$(q yt1 "$PG_DB" "SHOW data_checksums;")"
def_cc="$(q yt1 postgres "SELECT e->>'value' FROM jsonb_array_elements(yt_info('d')::jsonb) e WHERE e->>'name'='def_cluster_commit';")"
def_sc="$(q yt1 "$PG_DB" "SELECT (yt_ct_decode('')::jsonb)->'value'->'Table'->>'sequential_consistency';")"
def_tbl_cc="$(q yt1 "$PG_DB" "SELECT COALESCE(((yt_ct_decode('')::jsonb)->'value'->'Table'->>'cluster_commit'), 'inherit_default');")"
min_sz="$(q yt1 postgres "SELECT value FROM public.yt_config WHERE module='C' AND name='min_cluster_size';")"

echo "[yt-setup] Engine: ${ver%% on *}"
echo "[yt-setup] PG 18 defaults: io_method=$iom data_checksums=$chk"
echo "[yt-setup] Cluster config: min_cluster_size=$min_sz def_cluster_commit=$def_cc table_cluster_commit=$def_tbl_cc sequential_consistency=$def_sc"
echo "[yt-setup] Roster (module=N):"
q yt1 postgres "SELECT '  ' || name || ' -> ' || value FROM public.yt_config WHERE module='N' ORDER BY value;"
echo "[yt-setup] YT Cluster 1.21.3 is ready."
