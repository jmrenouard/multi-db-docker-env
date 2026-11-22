#!/usr/bin/env bash
# pg-logical functional and empirical limits test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"
D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
PUB="pg_logical_pub"
SUB="pg_logical_sub"
mkdir -p reports
REP="reports/test_pg_logical_$(date +%Y%m%d_%H%M%S).md"
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
rsub() {
    qn "$SUB" "ALTER SUBSCRIPTION sub_logical REFRESH PUBLICATION WITH (copy_data=false);" >/dev/null
    weq "$SUB" "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';" "0" 15
}

echo "# pg-logical Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. Health & uni-directional replication
wl="$(qn "$PUB" "SHOW wal_level;")"
wk="$(qn "$SUB" "SELECT count(*) FROM pg_stat_subscription WHERE subname='sub_logical' AND pid IS NOT NULL;")"
[ "$wl" = "logical" ] && [ "$wk" -ge 1 ] \
    && ok "Health OK: wal_level=$wl active_workers=$wk" || bad "Health check failed: wl=$wl wk=$wk"

qn "$PUB" "INSERT INTO accounts (owner, email, balance) VALUES ('pub_a','pa@lab',500),('pub_b','pb@lab',700);" >/dev/null
weq "$SUB" "SELECT count(*) FROM accounts;" "2" 15 \
    && ok "Uni-directional pub -> sub replicated 2/2 rows" || bad "Initial pub -> sub replication failed"

qn "$SUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (8001, 'sub_only','subonly@lab',99);" >/dev/null
sleep 2
[ "$(qn "$PUB" "SELECT count(*) FROM accounts WHERE id=8001;")" = "0" ] \
    && ok "Subscriber local write did not replicate back to publisher (strictly uni-directional)" \
    || bad "Unexpected reverse replication"

# 2. Keyless table UPDATE/DELETE failure (SQLSTATE 55000) -> surrogate PK fix
for n in "$PUB" "$SUB"; do
    qn "$n" "CREATE TABLE IF NOT EXISTS logical_nokey (tid INT, bid INT, aid INT, delta INT);" >/dev/null
done
rsub
qn "$PUB" "INSERT INTO logical_nokey VALUES (1, 1, 1, 50);" >/dev/null
weq "$SUB" "SELECT count(*) FROM logical_nokey;" "1" 15 \
    && ok "Keyless INSERT replicated to subscriber" || bad "Keyless INSERT failed"

ue="$(qraw "$PUB" "UPDATE logical_nokey SET delta=999 WHERE aid=1;")"
de="$(qraw "$PUB" "DELETE FROM logical_nokey WHERE aid=1;")"
echo "$ue" | grep -q "55000" && echo "$de" | grep -q "55000" \
    && lim "Keyless UPDATE/DELETE rejected (SQLSTATE 55000): $(echo "$ue" | grep 'ERROR:' | head -n 1)" \
    || bad "Expected SQLSTATE 55000: $ue"

for n in "$PUB" "$SUB"; do
    qn "$n" "ALTER TABLE logical_nokey ADD COLUMN hid BIGSERIAL PRIMARY KEY;" >/dev/null
done
rsub
qn "$PUB" "UPDATE logical_nokey SET delta=999 WHERE aid=1;" >/dev/null
weq "$SUB" "SELECT delta FROM logical_nokey WHERE aid=1;" "999" 15 \
    && ok "Surrogate PK restored UPDATE convergence on subscriber" || bad "Surrogate PK UPDATE failed"

# 3. ALTER TABLE ADD COLUMN non-propagation & TRUNCATE propagation
for n in "$PUB" "$SUB"; do
    qn "$n" "CREATE TABLE IF NOT EXISTS ddl_probe (id INT PRIMARY KEY, v TEXT);" >/dev/null
done
rsub
qn "$PUB" "INSERT INTO ddl_probe VALUES (1,'a'),(2,'b');" >/dev/null
weq "$SUB" "SELECT count(*) FROM ddl_probe;" "2" 15
qn "$PUB" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
sleep 2
[ "$(qn "$SUB" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';")" = "0" ] \
    && lim "ALTER TABLE ADD COLUMN did not auto-propagate to subscriber" || bad "Unexpected DDL propagation"

qn "$SUB" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
qn "$PUB" "TRUNCATE TABLE ddl_probe;" >/dev/null
weq "$SUB" "SELECT count(*) FROM ddl_probe;" "0" 15 \
    && ok "TRUNCATE TABLE propagated to subscriber" || bad "TRUNCATE propagation failed"

# 4. Sequence non-synchronization trap (post-failover 23505 collision)
for n in "$PUB" "$SUB"; do
    qn "$n" "CREATE TABLE IF NOT EXISTS seq_trap (id SERIAL PRIMARY KEY, payload TEXT);" >/dev/null
done
rsub
qn "$PUB" "INSERT INTO seq_trap (payload) SELECT 'pub_' || g FROM generate_series(1, 50) g;" >/dev/null
weq "$SUB" "SELECT count(*) FROM seq_trap;" "50" 15 \
    && ok "50 rows replicated into seq_trap on subscriber" || bad "seq_trap replication failed"

pub_seq="$(qn "$PUB" "SELECT last_value || '|' || is_called FROM seq_trap_id_seq;")"
sub_seq="$(qn "$SUB" "SELECT last_value || '|' || is_called FROM seq_trap_id_seq;")"
promo_err="$(qraw "$SUB" "INSERT INTO seq_trap (payload) VALUES ('after_failover');")"
if ( [ "$sub_seq" = "1|false" ] || [ "$sub_seq" = "1|f" ] ) && echo "$promo_err" | grep -q "23505"; then
    lim "Sequence non-sync trap confirmed: pub_seq=$pub_seq sub_seq=$sub_seq -> promotion insert hit SQLSTATE 23505"
else
    bad "Expected sequence trap 1|f + 23505, got pub=$pub_seq sub=$sub_seq err=$promo_err"
fi
qn "$SUB" "SELECT setval('seq_trap_id_seq', (SELECT max(id) FROM seq_trap));" >/dev/null
fixed_id="$(qn "$SUB" "INSERT INTO seq_trap (payload) VALUES ('after_setval') RETURNING id;" | head -n 1 | tr -d '[:space:]')"
[ "$fixed_id" = "51" ] \
    && ok "Manual setval() remediation restored sequence continuity (next id=$fixed_id)" \
    || bad "setval remediation failed: id=$fixed_id"

# 5. Local write collision on subscriber (23505 apply worker halt)
pre_err="$(qn "$SUB" "SELECT apply_error_count FROM pg_stat_subscription_stats WHERE subname='sub_logical';")"
qn "$SUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (9501, 'sub_local', 'col9501@lab', 10);" >/dev/null
qn "$PUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (9501, 'pub_win', 'pub9501@lab', 20);" >/dev/null
post_err="$pre_err"
for _ in $(seq 1 10); do
    post_err="$(qn "$SUB" "SELECT apply_error_count FROM pg_stat_subscription_stats WHERE subname='sub_logical';")"
    [ "$post_err" -gt "$pre_err" ] && break
    sleep 1
done
col_log="$(docker logs --tail 40 "$SUB" 2>&1 | grep -E "23505|duplicate key" | tail -n 1 || true)"
[ "$post_err" -gt "$pre_err" ] && [ -n "$col_log" ] \
    && lim "Local subscriber write collision halted apply worker (errors $pre_err->$post_err, SQLSTATE 23505)" \
    || bad "Expected subscriber apply 23505 halt missed"

qn "$SUB" "DELETE FROM accounts WHERE id=9501;" >/dev/null
weq "$SUB" "SELECT owner FROM accounts WHERE id=9501;" "pub_win" 20 \
    && ok "Deleting colliding local row unblocked apply worker and converged id=9501" \
    || bad "Apply worker recovery failed"

# 6. Feature probes (advisory_lock, LISTEN/NOTIFY, TEMP TABLE)
qn "$PUB" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 &
lp=$!
sleep 1
g2="$(qn "$SUB" "SELECT pg_try_advisory_lock(4242);")"
wait "$lp" || true
[ "$g2" = "t" ] && lim "pg_advisory_lock is node-local (subscriber acquired 4242: $g2)" || bad "Advisory lock unexpected"

TMP_LOG=$(mktemp)
trap 'rm -f "$TMP_LOG"' EXIT
docker exec -e PGPASSWORD="$P" "$SUB" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_log; SELECT pg_sleep(3);'" >"$TMP_LOG" 2>&1 &
lnp=$!
sleep 1
qn "$PUB" "NOTIFY ch_log, 'cross';" >/dev/null
wait "$lnp" || true
! grep -q "cross" "$TMP_LOG" && lim "LISTEN/NOTIFY is node-local (0 cross-node events)" || bad "Unexpected NOTIFY"

te="$(qraw "$PUB" "CREATE TEMP TABLE tmp_log (x INT); INSERT INTO tmp_log VALUES (1);")"
[ "$(qn "$SUB" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_log';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" \
    && ok "TEMP TABLE is session-local" || bad "TEMP TABLE unexpected"

# 7. Subscriber outage -> logical slot WAL retention -> catch-up
docker stop "$SUB" >/dev/null
for k in 1 2 3 4 5; do
    qn "$PUB" "INSERT INTO accounts (owner, email, balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null
done
si="$(qn "$PUB" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name='sub_logical';")"
sa="${si%%|*}"
wl_b="${si##*|}"
( [ "$sa" = "false" ] || [ "$sa" = "f" ] ) && [ "${wl_b:-0}" -gt 0 ] \
    && ok "Subscriber outage write OK; logical slot active=$sa WAL retained=${wl_b}B" \
    || bad "Logical slot state unexpected: $si"

docker start "$SUB" >/dev/null
until docker exec -e PGPASSWORD="$P" "$SUB" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
weq "$SUB" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "5" 30 \
    && ok "Subscriber caught up all 5 outage rows" || bad "Subscriber outage catch-up failed"

echo "=========================================================="
echo "pg-logical Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
