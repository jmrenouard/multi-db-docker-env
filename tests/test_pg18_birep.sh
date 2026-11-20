#!/usr/bin/env bash
# pg18-birep functional, native uuidv7(), PG 18 conflict stats, and limits test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"; D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
N1="pg18_birep_node1"; N2="pg18_birep_node2"; HAP="haproxy_pg18_birep"
mkdir -p reports; REP="reports/test_pg18_birep_$(date +%Y%m%d_%H%M%S).md"
PASS=0; FAIL=0; LIMIT=0
log() { echo "$1"; echo "$1" >> "$REP"; }
ok() { PASS=$((PASS+1)); log "[PASS] $1"; }
bad() { FAIL=$((FAIL+1)); log "[FAIL] $1"; }
lim() { LIMIT=$((LIMIT+1)); log "[EXPECTED_LIMITATION] $1"; }
qn() { docker exec -e PGPASSWORD="$P" "$1" psql -q -v ON_ERROR_STOP=1 -U "$U" -d "$D" -tAc "$2"; }
qraw() { docker exec -e PGPASSWORD="$P" "$1" psql -v VERBOSITY=verbose -v ON_ERROR_STOP=1 -U "$U" -d "$D" -c "$2" 2>&1 || true; }
weq() {
    local i=0 g=""
    while [ "$i" -lt "${4:-20}" ]; do
        g="$(qn "$1" "$2" 2>/dev/null | tr -d '[:space:]' || true)"
        [ "$g" = "$3" ] && return 0; sleep 1; i=$((i+1))
    done; return 1
}
rsub() {
    qn "$N1" "ALTER SUBSCRIPTION sub_from_node2 REFRESH PUBLICATION WITH (copy_data=false);" >/dev/null
    qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 REFRESH PUBLICATION WITH (copy_data=false);" >/dev/null
    weq "$N1" "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';" "0" 15
    weq "$N2" "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';" "0" 15
}
psub() {
    qn "$1" "ALTER SUBSCRIPTION ${2} DISABLE;" >/dev/null
    weq "$1" "SELECT count(*) FROM pg_stat_subscription WHERE subname='${2}' AND pid IS NOT NULL;" "0" 15
}
skerr() {
    local lsn; lsn="$(docker logs --tail 60 "$1" 2>&1 | sed -n 's/.*finished at \([0-9A-F]\+\/[0-9A-F]\+\).*/\1/p' | tail -n 1 || true)"
    [ -n "$lsn" ] && qn "$1" "ALTER SUBSCRIPTION ${2} SKIP (lsn='${lsn}');" >/dev/null 2>&1 || true
}
cs() { qn "$1" "SELECT ${3} FROM pg_stat_subscription_stats WHERE subname='${2}';"; }
echo "# pg18-birep Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. PG 18 health & HAProxy
ver="$(qn "$N1" "SELECT version();")"; wl="$(qn "$N1" "SHOW wal_level;")"; tc="$(qn "$N1" "SHOW track_commit_timestamp;")"
iom="$(qn "$N1" "SHOW io_method;")"; chk="$(qn "$N1" "SHOW data_checksums;")"
w1="$(qn "$N1" "SELECT count(*) FROM pg_stat_subscription WHERE pid IS NOT NULL;")"
w2="$(qn "$N2" "SELECT count(*) FROM pg_stat_subscription WHERE pid IS NOT NULL;")"
echo "$ver" | grep -q "PostgreSQL 18" && [ "$wl" = "logical" ] && [ "$tc" = "on" ] && [ "$w1" -ge 1 ] && [ "$w2" -ge 1 ] \
    && ok "PG 18 OK: wl=$wl commit_ts=$tc io=$iom chk=$chk w=${w1}/${w2}" || bad "Health: $wl $tc"
ips=""
for _ in 1 2 3 4 5 6; do
    ips+="$(docker exec -e PGPASSWORD="$P" "$N1" psql -h "$HAP" -p 5432 -U "$U" -d "$D" -tAc "SELECT inet_server_addr();" 2>/dev/null | tr -d '[:space:]' || true)\n"
done
uip="$(printf "%b" "$ips" | grep -v '^$' | sort -u | wc -l)"
sok="$(docker exec "$HAP" wget -qO- -T 3 http://127.0.0.1:8404/stats 2>/dev/null | grep -c "pg18_birep_nodes" || true)"
pok="$(docker port "$HAP" | grep -c "127.0.0.1:1554" || true)"
[ "$uip" -ge 2 ] && [ "$sok" -ge 1 ] && [ "$pok" -ge 2 ] && ok "HAProxy RR hit $uip nodes, stats up" || bad "HAProxy: $uip $sok $pok"

# 2. Bidirectional + concurrent writes (step-2 sequence)
qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('a1','a@lab',500),('b1','b@lab',600);" >/dev/null
qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('c2','c@lab',700),('d2','d@lab',800);" >/dev/null
( for i in $(seq 1 10); do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('cn1_${i}','cn1_${i}@lab',100);" >/dev/null; done ) & p1=$!
( for i in $(seq 1 10); do qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('cn2_${i}','cn2_${i}@lab',200);" >/dev/null; done ) & p2=$!
wait "$p1" "$p2"
weq "$N1" "SELECT count(*) FROM accounts;" "24" 20 && weq "$N2" "SELECT count(*) FROM accounts;" "24" 20 && ok "Bidirectional writes converged (24/24)" || bad "Accounts mismatch"

# 3. Native PG 18 uuidv7() zero-collision proof + monotonic B-tree keys
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS uuidv7_orders (id UUID PRIMARY KEY DEFAULT uuidv7(), node_src TEXT NOT NULL, seq_n INT NOT NULL);" >/dev/null; done
rsub
( for i in $(seq 1 25); do qn "$N1" "INSERT INTO uuidv7_orders (node_src,seq_n) VALUES ('n1',${i});" >/dev/null; done ) & u1=$!
( for i in $(seq 1 25); do qn "$N2" "INSERT INTO uuidv7_orders (node_src,seq_n) VALUES ('n2',${i});" >/dev/null; done ) & u2=$!
wait "$u1" "$u2"
weq "$N1" "SELECT count(*) FROM uuidv7_orders;" "50" 20 && weq "$N2" "SELECT count(*) FROM uuidv7_orders;" "50" 20 && ok "uuidv7() dual-node writes converged 50/50 (0 collisions)" || bad "uuidv7 mismatch"
inv="$(qn "$N1" "WITH o AS (SELECT node_src,seq_n,id,lag(id) OVER (PARTITION BY node_src ORDER BY seq_n) AS p FROM uuidv7_orders) SELECT count(*) FROM o WHERE p IS NOT NULL AND id<=p;")"
uerr="$(cs "$N1" sub_from_node2 "apply_error_count+confl_insert_exists")"
[ "$inv" = "0" ] && [ "$uerr" = "0" ] && ok "uuidv7() monotonic B-tree order verified (inv=0 err=0)" || bad "uuidv7 inv=$inv err=$uerr"

# 4. Contrast: naive SERIAL PK collision (23505 + confl_insert_exists)
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS uncoord_serial (id SERIAL PRIMARY KEY, src TEXT);" >/dev/null; done
rsub; psub "$N2" "sub_from_node1"
qn "$N1" "INSERT INTO uncoord_serial (src) VALUES ('n1');" >/dev/null
qn "$N2" "INSERT INTO uncoord_serial (src) VALUES ('n2');" >/dev/null
qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
ec=0; for _ in $(seq 1 10); do ec="$(cs "$N2" sub_from_node1 confl_insert_exists)"; [ "${ec:-0}" -ge 1 ] && break; sleep 1; done
[ "${ec:-0}" -ge 1 ] && lim "SERIAL PK collision halted apply (confl_insert_exists=$ec, 23505)" || bad "Expected 23505"
qn "$N2" "DELETE FROM uncoord_serial WHERE id=1 AND src='n2';" >/dev/null
skerr "$N1" "sub_from_node2"; weq "$N2" "SELECT src FROM uncoord_serial WHERE id=1;" "n1" 15 || true

# 5. Keyless table UPDATE/DELETE (55000) -> PK fix
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS pgbench_history_nokey (tid INT, bid INT, aid INT, delta INT);" >/dev/null; done
rsub; qn "$N1" "INSERT INTO pgbench_history_nokey VALUES (1,1,1,50);" >/dev/null
weq "$N2" "SELECT count(*) FROM pgbench_history_nokey;" "1" 15 && ok "Keyless INSERT replicated" || bad "Keyless INSERT failed"
ue="$(qraw "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;")"
de="$(qraw "$N1" "DELETE FROM pgbench_history_nokey WHERE aid=1;")"
echo "$ue" | grep -q "55000" && echo "$de" | grep -q "55000" && lim "Keyless UPDATE/DELETE rejected (55000)" || bad "Expected 55000"
for n in "$N1" "$N2"; do qn "$n" "ALTER TABLE pgbench_history_nokey ADD COLUMN hid BIGSERIAL PRIMARY KEY;" >/dev/null; done
rsub; qn "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;" >/dev/null
weq "$N2" "SELECT delta FROM pgbench_history_nokey WHERE aid=1;" "999" 15 && ok "Surrogate PK fixed UPDATE convergence" || bad "PK UPDATE failed"

# 6. Lost Update + confl_update_origin_differs
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9001,'lww','lww@lab',1000.00);" >/dev/null
weq "$N2" "SELECT balance::int FROM accounts WHERE id=9001;" "1000" 15
psub "$N1" "sub_from_node2"; psub "$N2" "sub_from_node1"
qn "$N1" "UPDATE accounts SET balance=balance+100 WHERE id=9001;" >/dev/null
qn "$N2" "UPDATE accounts SET balance=balance-30 WHERE id=9001;" >/dev/null
qn "$N1" "ALTER SUBSCRIPTION sub_from_node2 ENABLE;" >/dev/null; qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
sleep 3
b1="$(qn "$N1" "SELECT balance FROM accounts WHERE id=9001;")"; b2="$(qn "$N2" "SELECT balance FROM accounts WHERE id=9001;")"
u1="$(cs "$N1" sub_from_node2 confl_update_origin_differs)"; u2="$(cs "$N2" sub_from_node1 confl_update_origin_differs)"
( [ "$b1" != "1070.00" ] || [ "$b2" != "1070.00" ] ) && lim "Lost Update (+100/-30): n1=$b1 n2=$b2; confl_update_origin_differs=$u1/$u2" || bad "Unexpected 1070.00"

# 7. UNIQUE(email) + PG 18 confl_multiple_unique_conflicts
pre="$(cs "$N2" sub_from_node1 confl_insert_exists)"
psub "$N1" "sub_from_node2"; psub "$N2" "sub_from_node1"
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9101,'u1','dup@lab',10);" >/dev/null
qn "$N2" "INSERT INTO accounts (id,owner,email,balance) VALUES (9102,'u2','dup@lab',20);" >/dev/null
qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
post="$pre"; for _ in $(seq 1 10); do post="$(cs "$N2" sub_from_node1 confl_insert_exists)"; [ "$post" -gt "$pre" ] && break; sleep 1; done
[ "$post" -gt "$pre" ] && lim "UNIQUE(email) conflict stalled apply (confl_insert_exists $pre->$post, 23505)" || bad "UNIQUE missed"
qn "$N2" "DELETE FROM accounts WHERE id=9102;" >/dev/null; weq "$N2" "SELECT id FROM accounts WHERE email='dup@lab';" "9101" 15 || true

psub "$N2" "sub_from_node1"
qn "$N2" "INSERT INTO accounts (id,owner,email,balance) VALUES (9201,'m1','m1@lab',10),(9202,'m2','m2@lab',20);" >/dev/null
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9201,'m_both','m2@lab',30);" >/dev/null
qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
muc=0; for _ in $(seq 1 10); do muc="$(cs "$N2" sub_from_node1 confl_multiple_unique_conflicts)"; [ "${muc:-0}" -ge 1 ] && break; sleep 1; done
[ "${muc:-0}" -ge 1 ] && lim "PG 18 confl_multiple_unique_conflicts=$muc triggered" || bad "Expected muc>=1"
qn "$N2" "DELETE FROM accounts WHERE id IN (9201,9202);" >/dev/null
weq "$N2" "SELECT owner FROM accounts WHERE id=9201;" "m_both" 15 || true
qn "$N1" "ALTER SUBSCRIPTION sub_from_node2 ENABLE;" >/dev/null; sleep 2; skerr "$N1" "sub_from_node2"

# 8. DDL, T18 sequence probe, local features, and outage catch-up
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS ddl_probe (id INT PRIMARY KEY, v TEXT);" >/dev/null; done
rsub; qn "$N1" "INSERT INTO ddl_probe VALUES (1,'a'),(2,'b');" >/dev/null; weq "$N2" "SELECT count(*) FROM ddl_probe;" "2" 15
qn "$N1" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null; sleep 2
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';")" = "0" ] \
    && lim "ALTER TABLE ADD COLUMN did not auto-propagate" || bad "Unexpected DDL propagation"
qn "$N2" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
qn "$N1" "TRUNCATE TABLE ddl_probe;" >/dev/null; weq "$N2" "SELECT count(*) FROM ddl_probe;" "0" 15 && ok "TRUNCATE propagated" || bad "TRUNCATE missed"

echo "$(qraw "$N1" "CREATE PUBLICATION p_seq FOR ALL SEQUENCES;")" | grep -q "42601" \
    && lim "PG 18.6 FOR ALL SEQUENCES rejected (42601)" || bad "Expected 42601"
qn "$N1" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 & lp=$!; sleep 1
[ "$(qn "$N2" "SELECT pg_try_advisory_lock(4242);")" = "t" ] && lim "pg_advisory_lock node-local" || bad "Advisory lock"; wait "$lp" || true
docker exec -e PGPASSWORD="$P" "$N2" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_b18; SELECT pg_sleep(3);'" >/tmp/lb18.out 2>&1 & lnp=$!; sleep 1
qn "$N1" "NOTIFY ch_b18, 'cross';" >/dev/null; wait "$lnp" || true
! grep -q "cross" /tmp/lb18.out && lim "LISTEN/NOTIFY node-local" || bad "Unexpected NOTIFY"; rm -f /tmp/lb18.out
te="$(qraw "$N1" "CREATE TEMP TABLE tmp_b18 (x INT); INSERT INTO tmp_b18 VALUES (1);")"
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_b18';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" && ok "TEMP TABLE session-local" || bad "TEMP TABLE"

docker stop "$N2" >/dev/null
for k in 1 2 3 4 5; do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null; done
si="$(qn "$N1" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name='sub_from_node1';")"
sa="${si%%|*}"; wl_b="${si##*|}"
( [ "$sa" = "false" ] || [ "$sa" = "f" ] ) && [ "${wl_b:-0}" -gt 0 ] && ok "Outage write OK; slot=$sa WAL=${wl_b}B" || bad "Slot: $si"
docker start "$N2" >/dev/null
until docker exec -e PGPASSWORD="$P" "$N2" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
weq "$N2" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "5" 30 && ok "Node2 caught up 5/5" || bad "Outage catch-up failed"

echo "pg18-birep Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT (Report: $REP)"
[ "$FAIL" -eq 0 ] || exit 1
