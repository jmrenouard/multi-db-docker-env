#!/usr/bin/env bash
# pg18-streaming functional, PG 18 capabilities, limits, and failover test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"
D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
PRI="pg18_stream_primary"
STB="pg18_stream_standby"
mkdir -p reports
REP="reports/test_pg18_streaming_$(date +%Y%m%d_%H%M%S).md"
PASS=0
FAIL=0
LIMIT=0

log() { echo "$1"; echo "$1" >> "$REP"; }
ok() { PASS=$((PASS + 1)); log "[PASS] $1"; }
bad() { FAIL=$((FAIL + 1)); log "[FAIL] $1"; }
lim() { LIMIT=$((LIMIT + 1)); log "[EXPECTED_LIMITATION] $1"; }
qn() { docker exec -e PGPASSWORD="$P" "$1" psql -q -v ON_ERROR_STOP=1 -U "$U" -d "$D" -tAc "$2"; }
qraw() { docker exec -e PGPASSWORD="$P" "$1" psql -v VERBOSITY=verbose -v ON_ERROR_STOP=1 -U "$U" -d "$D" -c "$2" 2>&1 || true; }
weq() {
    local i=0 g=""
    while [ "$i" -lt "${4:-20}" ]; do
        g="$(qn "$1" "$2" 2>/dev/null | tr -d '[:space:]' || true)"
        [ "$g" = "$3" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

echo "# pg18-streaming Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. PG 18 version, AIO io_method, checksums, uuidv7(), and async health
ver="$(qn "$PRI" "SELECT version();")"
iom="$(qn "$PRI" "SHOW io_method;")"
iow="$(qn "$PRI" "SHOW io_workers;")"
chk="$(qn "$PRI" "SHOW data_checksums;")"
u7="$(qn "$PRI" "SELECT uuidv7();")"
echo "$ver" | grep -q "PostgreSQL 18" && [ -n "$u7" ] \
    && ok "PG 18 verified: io_method=$iom io_workers=$iow data_checksums=$chk uuidv7=$u7" \
    || bad "PG 18 probe mismatch: ver=$ver iom=$iom chk=$chk"

wl="$(qn "$PRI" "SHOW wal_level;")"
pr="$(qn "$PRI" "SELECT pg_is_in_recovery();")"
sr="$(qn "$STB" "SELECT pg_is_in_recovery();")"
sa="$(qn "$PRI" "SELECT active FROM pg_replication_slots WHERE slot_name='slot_pg18_standby';")"
st="$(qn "$PRI" "SELECT sync_state FROM pg_stat_replication WHERE application_name='pg18_stream_standby';")"
[ "$wl" = "replica" ] && [ "$pr" = "f" ] && [ "$sr" = "t" ] && [ "$sa" = "t" ] && [ "$st" = "async" ] \
    && ok "Async streaming healthy: wal_level=$wl primary_rec=$pr standby_rec=$sr slot_active=$sa sync_state=$st" \
    || bad "Async health mismatch: wl=$wl pr=$pr sr=$sr sa=$sa st=$st"

qn "$PRI" "INSERT INTO accounts (owner, email, balance) VALUES ('async_a','aa@lab',500),('async_b','ab@lab',750);" >/dev/null
weq "$STB" "SELECT count(*) FROM accounts;" "2" 15 \
    && ok "Async physical WAL replicated 2/2 rows to standby" || bad "Async replication count mismatch"

# 2. Switch to sync mode
qn "$PRI" "ALTER SYSTEM SET synchronous_standby_names = 'pg18_stream_standby';" >/dev/null
qn "$PRI" "ALTER SYSTEM SET synchronous_commit = 'on';" >/dev/null
qn "$PRI" "SELECT pg_reload_conf();" >/dev/null
weq "$PRI" "SELECT sync_state FROM pg_stat_replication WHERE application_name='pg18_stream_standby';" "sync" 15 \
    && ok "Switched to sync mode: sync_state=sync" || bad "Failed switching to sync mode"

qn "$PRI" "INSERT INTO accounts (owner, email, balance) VALUES ('sync_c','sc@lab',900),('sync_d','sd@lab',1100);" >/dev/null
weq "$STB" "SELECT count(*) FROM accounts;" "4" 10 \
    && ok "Sync mode replicated 4/4 rows with RPO=0" || bad "Sync replication count mismatch"

# 3. Read-only standby enforcement (SQLSTATE 25006)
ro_err="$(qraw "$STB" "INSERT INTO accounts (owner, email, balance) VALUES ('ro_fail','ro@lab',10);")"
echo "$ro_err" | grep -q "25006" \
    && lim "Read-only standby rejected write (SQLSTATE 25006): $(echo "$ro_err" | grep 'ERROR:' | head -n 1)" \
    || bad "Expected SQLSTATE 25006 on standby write, got: $ro_err"

# 4. Physical DDL, SAVEPOINT, and keyless table replication
docker exec -i -e PGPASSWORD="$P" "$PRI" psql -v ON_ERROR_STOP=1 -U "$U" -d "$D" >/dev/null <<'SQL'
CREATE TABLE stream_nokey (tid INT, aid INT, delta INT);
INSERT INTO stream_nokey VALUES (1, 10, 50), (1, 11, 60);
UPDATE stream_nokey SET delta = 999 WHERE aid = 10;
DELETE FROM stream_nokey WHERE aid = 11;
ALTER TABLE stream_nokey ADD COLUMN extra TEXT DEFAULT 'v1';
BEGIN;
INSERT INTO stream_nokey (tid, aid, delta, extra) VALUES (2, 12, 70, 'sp');
SAVEPOINT sp1;
INSERT INTO stream_nokey (tid, aid, delta, extra) VALUES (2, 13, 80, 'rolled');
ROLLBACK TO SAVEPOINT sp1;
COMMIT;
SQL
weq "$STB" "SELECT count(*) || '|' || max(delta) || '|' || min(extra) FROM stream_nokey;" "2|999|sp" 15 \
    && ok "Physical WAL replicated keyless UPDATE/DELETE, ALTER TABLE ADD COLUMN, and SAVEPOINT atomically" \
    || bad "Physical DDL/keyless replication mismatch"

# 5. Standby TEMP TABLE limit (25006)
tmp_err="$(qraw "$STB" "CREATE TEMP TABLE tmp_stb (x INT);")"
echo "$tmp_err" | grep -q "25006" \
    && lim "Standby rejected CREATE TEMP TABLE (SQLSTATE 25006)" \
    || bad "Expected 25006 on standby TEMP TABLE, got: $tmp_err"

# 6. Sync stall proof + async standby outage WAL retention
docker stop "$STB" >/dev/null
docker exec -e PGPASSWORD="$P" "$PRI" psql -v VERBOSITY=verbose -U "$U" -d "$D" -c \
    "INSERT INTO accounts (owner, email, balance) VALUES ('stall_test','stall@lab',1);" >/tmp/pg18_sync_stall.out 2>&1 &
spid=$!
weq "$PRI" "SELECT count(*) FROM pg_stat_activity WHERE wait_event='SyncRep';" "1" 10 || true
syncrep_cnt="$(qn "$PRI" "SELECT count(*) FROM pg_stat_activity WHERE wait_event='SyncRep';")"
qn "$PRI" "SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE wait_event='SyncRep';" >/dev/null || true
wait "$spid" || true
stall_out="$(cat /tmp/pg18_sync_stall.out 2>/dev/null || true)"
rm -f /tmp/pg18_sync_stall.out
[ "${syncrep_cnt:-0}" -ge 1 ] \
    && lim "Sync primary stalled on SyncRep wait when sync standby stopped (count=$syncrep_cnt)" \
    || bad "Expected SyncRep stall on primary, got count=$syncrep_cnt out=$stall_out"

qn "$PRI" "ALTER SYSTEM SET synchronous_standby_names = '';" >/dev/null
qn "$PRI" "SELECT pg_reload_conf();" >/dev/null
for k in 1 2 3 4 5 6 7 8 9 10; do
    qn "$PRI" "INSERT INTO accounts (owner, email, balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null
done
si="$(qn "$PRI" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name='slot_pg18_standby';")"
slot_a="${si%%|*}"
wal_b="${si##*|}"
( [ "$slot_a" = "false" ] || [ "$slot_a" = "f" ] ) && [ "${wal_b:-0}" -gt 0 ] \
    && ok "Async outage write OK; physical slot active=$slot_a WAL retained=${wal_b}B" \
    || bad "Unexpected physical slot state during outage: $si"

docker start "$STB" >/dev/null
until docker exec -e PGPASSWORD="$P" "$STB" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
weq "$STB" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "10" 30 \
    && ok "Standby caught up 10/10 outage rows from physical slot" \
    || bad "Standby outage catch-up failed"

# 7. Sequence continuity after pg_promote() failover
qn "$PRI" "CREATE TABLE seq_promo_test (id SERIAL PRIMARY KEY, payload TEXT); INSERT INTO seq_promo_test (payload) SELECT 'pri_' || g FROM generate_series(1, 50) g;" >/dev/null
weq "$STB" "SELECT count(*) FROM seq_promo_test;" "50" 15 \
    && ok "50 sequence-backed rows replicated to standby" || bad "seq_promo_test replication failed"

pri_lv="$(qn "$PRI" "SELECT last_value FROM seq_promo_test_id_seq;")"
stb_lv="$(qn "$STB" "SELECT last_value FROM seq_promo_test_id_seq;")"
docker stop "$PRI" >/dev/null
qn "$STB" "SELECT pg_promote(wait => true);" >/dev/null
weq "$STB" "SELECT pg_is_in_recovery();" "f" 15 \
    && ok "pg_promote() promoted standby to read-write primary (pg_is_in_recovery=f)" \
    || bad "Standby promotion failed"

next_id="$(qn "$STB" "INSERT INTO seq_promo_test (payload) VALUES ('post_promote') RETURNING id;" | head -n 1 | tr -d '[:space:]')"
[ "${next_id:-0}" -ge 51 ] \
    && ok "Sequence continuity preserved post-promotion: pri_lv=$pri_lv stb_lv=$stb_lv next_id=$next_id (zero 23505)" \
    || bad "Sequence discontinuity after promotion: next_id=$next_id"

echo "=========================================================="
echo "pg18-streaming Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
