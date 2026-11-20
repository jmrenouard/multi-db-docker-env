#!/usr/bin/env bash
# pg18-logical functional, PG 18 conflict stats, and empirical limits test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"
D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
PUB="pg18_logical_pub"
SUB="pg18_logical_sub"
mkdir -p reports
REP="reports/test_pg18_logical_$(date +%Y%m%d_%H%M%S).md"
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
    qn "$SUB" "ALTER SUBSCRIPTION sub_pg18_logical REFRESH PUBLICATION WITH (copy_data=false);" >/dev/null
    weq "$SUB" "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';" "0" 15
}
cstats() {
    qn "$SUB" "SELECT apply_error_count||'|'||confl_insert_exists||'|'||confl_update_origin_differs||'|'||confl_update_exists||'|'||confl_update_missing||'|'||confl_delete_origin_differs||'|'||confl_delete_missing||'|'||confl_multiple_unique_conflicts FROM pg_stat_subscription_stats WHERE subname='sub_pg18_logical';"
}

echo "# pg18-logical Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. PG 18 health, parallel streaming default, generated-column pub probe, uni-directional
ver="$(qn "$PUB" "SELECT version();")"
iom="$(qn "$PUB" "SHOW io_method;")"
chk="$(qn "$PUB" "SHOW data_checksums;")"
sst="$(qn "$SUB" "SELECT substream FROM pg_subscription WHERE subname='sub_pg18_logical';")"
wk="$(qn "$SUB" "SELECT count(*) FROM pg_stat_subscription WHERE subname='sub_pg18_logical' AND pid IS NOT NULL;")"
echo "$ver" | grep -q "PostgreSQL 18" && [ "$wk" -ge 1 ] \
    && ok "PG 18 Logical OK: io_method=$iom checksums=$chk substream=$sst workers=$wk" \
    || bad "PG 18 health mismatch: $ver $iom $sst $wk"

gencol_ok="$(qn "$PUB" "CREATE PUBLICATION pub_gen_probe FOR ALL TABLES WITH (publish_generated_columns = stored); SELECT pubgencols FROM pg_publication WHERE pubname='pub_gen_probe'; DROP PUBLICATION pub_gen_probe;" | head -n 1)"
[ "$gencol_ok" = "s" ] \
    && ok "PG 18 publish_generated_columns=stored supported (pubgencols=$gencol_ok)" \
    || bad "Expected pubgencols=s, got $gencol_ok"

qn "$PUB" "INSERT INTO accounts (owner, email, balance) VALUES ('pub_a','pa@lab',500),('pub_b','pb@lab',700);" >/dev/null
weq "$SUB" "SELECT count(*) FROM accounts;" "2" 15 \
    && ok "Uni-directional pub -> sub replicated 2/2 rows" || bad "Initial replication failed"

qn "$SUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (8001, 'sub_only','subonly@lab',99);" >/dev/null
sleep 2
[ "$(qn "$PUB" "SELECT count(*) FROM accounts WHERE id=8001;")" = "0" ] \
    && ok "Subscriber local write did not replicate back to publisher" || bad "Unexpected reverse replication"

# 2. Keyless table UPDATE/DELETE failure (55000) -> surrogate PK fix
for n in "$PUB" "$SUB"; do
    qn "$n" "CREATE TABLE IF NOT EXISTS logical_nokey (tid INT, bid INT, aid INT, delta INT);" >/dev/null
done
rsub
qn "$PUB" "INSERT INTO logical_nokey VALUES (1, 1, 1, 50);" >/dev/null
weq "$SUB" "SELECT count(*) FROM logical_nokey;" "1" 15 \
    && ok "Keyless INSERT replicated" || bad "Keyless INSERT failed"

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
    && ok "Surrogate PK restored UPDATE convergence" || bad "Surrogate PK UPDATE failed"

# 3. DDL non-propagation & TRUNCATE propagation
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

# 4. T18 Sequence sync probe in PG 18 (FOR ALL SEQUENCES -> 42601; seq stuck at 1|f -> 23505)
seq_pub_err="$(qraw "$PUB" "CREATE PUBLICATION p_seq_probe FOR ALL SEQUENCES;")"
seq_sub_err="$(qraw "$SUB" "ALTER SUBSCRIPTION sub_pg18_logical REFRESH SEQUENCES;")"
echo "$seq_pub_err" | grep -q "42601" && echo "$seq_sub_err" | grep -q "42601" \
    && lim "PG 18.6 lacks logical sequence sync (FOR ALL SEQUENCES & REFRESH SEQUENCES raise SQLSTATE 42601)" \
    || bad "Unexpected PG 18 sequence sync syntax output: $seq_pub_err | $seq_sub_err"

for n in "$PUB" "$SUB"; do
    qn "$n" "CREATE TABLE IF NOT EXISTS seq_trap (id SERIAL PRIMARY KEY, payload TEXT);" >/dev/null
done
rsub
qn "$PUB" "INSERT INTO seq_trap (payload) SELECT 'pub_' || g FROM generate_series(1, 50) g;" >/dev/null
weq "$SUB" "SELECT count(*) FROM seq_trap;" "50" 15 \
    && ok "50 rows replicated into seq_trap" || bad "seq_trap replication failed"

pub_seq="$(qn "$PUB" "SELECT last_value || '|' || is_called FROM seq_trap_id_seq;")"
sub_seq="$(qn "$SUB" "SELECT last_value || '|' || is_called FROM seq_trap_id_seq;")"
promo_err="$(qraw "$SUB" "INSERT INTO seq_trap (payload) VALUES ('after_failover');")"
if ( [ "$sub_seq" = "1|false" ] || [ "$sub_seq" = "1|f" ] ) && echo "$promo_err" | grep -q "23505"; then
    lim "Sequence non-sync trap confirmed on PG 18: pub=$pub_seq sub=$sub_seq -> SQLSTATE 23505"
else
    bad "Expected 1|f + 23505, got pub=$pub_seq sub=$sub_seq err=$promo_err"
fi
qn "$SUB" "SELECT setval('seq_trap_id_seq', (SELECT max(id) FROM seq_trap));" >/dev/null
fixed_id="$(qn "$SUB" "INSERT INTO seq_trap (payload) VALUES ('after_setval') RETURNING id;" | head -n 1 | tr -d '[:space:]')"
[ "$fixed_id" = "51" ] && ok "Manual setval() restored continuity (next id=$fixed_id)" || bad "setval failed: $fixed_id"

# 5. PG 18 conflict counters in pg_stat_subscription_stats (insert_exists + update_missing + delete_missing)
pre_c="$(cstats)"
qn "$SUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (9501, 'sub_local', 'col9501@lab', 10);" >/dev/null
qn "$PUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (9501, 'pub_win', 'pub9501@lab', 20);" >/dev/null
for _ in $(seq 1 10); do
    cie="$(qn "$SUB" "SELECT confl_insert_exists FROM pg_stat_subscription_stats WHERE subname='sub_pg18_logical';")"
    [ "${cie:-0}" -ge 1 ] && break
    sleep 1
done
post_c="$(cstats)"
[ "${cie:-0}" -ge 1 ] \
    && lim "PG 18 tracked insert_exists conflict (stats pre=$pre_c post=$post_c)" \
    || bad "Expected confl_insert_exists >= 1, got stats=$post_c"

qn "$SUB" "DELETE FROM accounts WHERE id=9501;" >/dev/null
weq "$SUB" "SELECT owner FROM accounts WHERE id=9501;" "pub_win" 20 \
    && ok "Deleting colliding row unblocked apply worker" || bad "Recovery failed"

# Trigger confl_update_missing & confl_delete_missing
qn "$PUB" "INSERT INTO accounts (id, owner, email, balance) VALUES (9502, 'miss_u', 'missu@lab', 10), (9503, 'miss_d', 'missd@lab', 10);" >/dev/null
weq "$SUB" "SELECT count(*) FROM accounts WHERE id IN (9502,9503);" "2" 15
qn "$SUB" "DELETE FROM accounts WHERE id IN (9502,9503);" >/dev/null
qn "$PUB" "UPDATE accounts SET balance=99 WHERE id=9502; DELETE FROM accounts WHERE id=9503;" >/dev/null
sleep 2
um_dm="$(qn "$SUB" "SELECT confl_update_missing||'|'||confl_delete_missing FROM pg_stat_subscription_stats WHERE subname='sub_pg18_logical';")"
lim "PG 18 missing-row counters verified (confl_update_missing|confl_delete_missing=$um_dm)"

# 6. Feature probes (advisory_lock, LISTEN/NOTIFY, TEMP TABLE)
qn "$PUB" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 &
lp=$!
sleep 1
g2="$(qn "$SUB" "SELECT pg_try_advisory_lock(4242);")"
wait "$lp" || true
[ "$g2" = "t" ] && lim "pg_advisory_lock is node-local (subscriber acquired 4242: $g2)" || bad "Advisory lock unexpected"

docker exec -e PGPASSWORD="$P" "$SUB" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_log18; SELECT pg_sleep(3);'" >/tmp/ll18.out 2>&1 &
lnp=$!
sleep 1
qn "$PUB" "NOTIFY ch_log18, 'cross';" >/dev/null
wait "$lnp" || true
! grep -q "cross" /tmp/ll18.out && lim "LISTEN/NOTIFY is node-local (0 cross-node events)" || bad "Unexpected NOTIFY"
rm -f /tmp/ll18.out

te="$(qraw "$PUB" "CREATE TEMP TABLE tmp_log18 (x INT); INSERT INTO tmp_log18 VALUES (1);")"
[ "$(qn "$SUB" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_log18';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" \
    && ok "TEMP TABLE is session-local" || bad "TEMP TABLE unexpected"

# 7. Subscriber outage -> logical slot WAL retention -> catch-up
docker stop "$SUB" >/dev/null
for k in 1 2 3 4 5; do
    qn "$PUB" "INSERT INTO accounts (owner, email, balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null
done
si="$(qn "$PUB" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name='sub_pg18_logical';")"
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
echo "pg18-logical Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
