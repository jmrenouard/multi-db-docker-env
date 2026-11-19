#!/usr/bin/env bash
# pg-birep functional and empirical limits test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"; D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
N1="pg_birep_node1"; N2="pg_birep_node2"; HAP="haproxy_pg_birep"
mkdir -p reports; REP="reports/test_pg_birep_$(date +%Y%m%d_%H%M%S).md"
PASS=0; FAIL=0; LIMIT=0
log() { echo "$1"; echo "$1" >> "$REP"; }
ok() { PASS=$((PASS+1)); log "[PASS] $1"; }
bad() { FAIL=$((FAIL+1)); log "[FAIL] $1"; }
lim() { LIMIT=$((LIMIT+1)); log "[EXPECTED_LIMITATION] $1"; }
qn() { docker exec -e PGPASSWORD="$P" "$1" psql -v ON_ERROR_STOP=1 -U "$U" -d "$D" -tAc "$2"; }
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
echo "# pg-birep Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. Health & HAProxy
wl="$(qn "$N1" "SHOW wal_level;")"; tc="$(qn "$N1" "SHOW track_commit_timestamp;")"
w1="$(qn "$N1" "SELECT count(*) FROM pg_stat_subscription WHERE pid IS NOT NULL;")"
w2="$(qn "$N2" "SELECT count(*) FROM pg_stat_subscription WHERE pid IS NOT NULL;")"
[ "$wl" = "logical" ] && [ "$tc" = "on" ] && [ "$w1" -ge 1 ] && [ "$w2" -ge 1 ] \
    && ok "Health OK: wal_level=$wl track_commit_timestamp=$tc workers=${w1}/${w2}" || bad "Health: $wl $tc"
ips=""
for _ in 1 2 3 4 5 6; do
    ip="$(docker exec -e PGPASSWORD="$P" "$N1" psql -h "$HAP" -p 5432 -U "$U" -d "$D" -tAc "SELECT inet_server_addr();" 2>/dev/null | tr -d '[:space:]' || true)"
    ips="${ips}${ip}\n"
done
uip="$(printf "%b" "$ips" | grep -v '^$' | sort -u | wc -l)"
sok="$(docker exec "$HAP" wget -qO- -T 3 http://127.0.0.1:8404/stats 2>/dev/null | grep -c "pg_birep_nodes" || true)"
pok="$(docker port "$HAP" | grep -c "127.0.0.1:1544" || true)"
[ "$uip" -ge 2 ] && [ "$sok" -ge 1 ] && [ "$pok" -ge 2 ] \
    && ok "HAProxy round-robin hit $uip nodes, stats up, localhost bound" || bad "HAProxy: $uip $sok $pok"

# 2. Bidirectional + concurrent writes
qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('a1','a@lab',500),('b1','b@lab',600);" >/dev/null
qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('c2','c@lab',700),('d2','d@lab',800);" >/dev/null
( for i in $(seq 1 10); do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('cn1_${i}','cn1_${i}@lab',100);" >/dev/null; done ) & p1=$!
( for i in $(seq 1 10); do qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('cn2_${i}','cn2_${i}@lab',200);" >/dev/null; done ) & p2=$!
wait "$p1" "$p2"
weq "$N1" "SELECT count(*) FROM accounts;" "24" 20 && weq "$N2" "SELECT count(*) FROM accounts;" "24" 20 \
    && ok "Bidirectional + concurrent writes converged (24/24)" || bad "Accounts mismatch"

# 3. Uncoordinated SERIAL PK collision (23505)
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS uncoord_serial (id SERIAL PRIMARY KEY, src TEXT);" >/dev/null; done; rsub
psub "$N2" "sub_from_node1"
qn "$N1" "INSERT INTO uncoord_serial (src) VALUES ('n1');" >/dev/null
qn "$N2" "INSERT INTO uncoord_serial (src) VALUES ('n2');" >/dev/null
qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
ec=0; for _ in $(seq 1 10); do ec="$(qn "$N2" "SELECT apply_error_count FROM pg_stat_subscription_stats WHERE subname='sub_from_node1';")"; [ "$ec" -ge 1 ] && break; sleep 1; done
el="$(docker logs --tail 35 "$N2" 2>&1 | grep -E "23505|duplicate key" | tail -n 1 || true)"
[ "$ec" -ge 1 ] && [ -n "$el" ] && lim "SERIAL PK collision halted apply (errors=$ec): $el" || bad "Expected 23505 missed"
qn "$N2" "DELETE FROM uncoord_serial WHERE id=1 AND src='n2';" >/dev/null
skerr "$N1" "sub_from_node2"; weq "$N2" "SELECT src FROM uncoord_serial WHERE id=1;" "n1" 15 || true

# 4. Keyless table UPDATE/DELETE limit (55000) -> PK fix
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS pgbench_history_nokey (tid INT, bid INT, aid INT, delta INT, mtime TIMESTAMPTZ DEFAULT now());" >/dev/null; done; rsub
qn "$N1" "INSERT INTO pgbench_history_nokey (tid,bid,aid,delta) VALUES (1,1,1,50);" >/dev/null
weq "$N2" "SELECT count(*) FROM pgbench_history_nokey;" "1" 15 && ok "Keyless INSERT replicated" || bad "Keyless INSERT failed"
ue="$(qraw "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;")"
de="$(qraw "$N1" "DELETE FROM pgbench_history_nokey WHERE aid=1;")"
echo "$ue" | grep -q "55000" && echo "$de" | grep -q "55000" \
    && lim "Keyless UPDATE/DELETE rejected (55000): $(echo "$ue" | grep 'ERROR:' | head -n 1)" || bad "Expected 55000: $ue"
for n in "$N1" "$N2"; do qn "$n" "ALTER TABLE pgbench_history_nokey ADD COLUMN hid BIGSERIAL PRIMARY KEY;" >/dev/null; done; rsub
qn "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;" >/dev/null
weq "$N2" "SELECT delta FROM pgbench_history_nokey WHERE aid=1;" "999" 15 && ok "Surrogate PK fixed UPDATE convergence" || bad "PK UPDATE failed"

# 5. Lost Update anomaly
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9001,'lww','lww@lab',1000.00);" >/dev/null
weq "$N2" "SELECT balance::int FROM accounts WHERE id=9001;" "1000" 15
psub "$N1" "sub_from_node2"; psub "$N2" "sub_from_node1"
qn "$N1" "UPDATE accounts SET balance=balance+100 WHERE id=9001;" >/dev/null
qn "$N2" "UPDATE accounts SET balance=balance-30 WHERE id=9001;" >/dev/null
qn "$N1" "ALTER SUBSCRIPTION sub_from_node2 ENABLE;" >/dev/null; qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
sleep 3; b1="$(qn "$N1" "SELECT balance FROM accounts WHERE id=9001;")"; b2="$(qn "$N2" "SELECT balance FROM accounts WHERE id=9001;")"
[ "$b1" != "1070.00" ] || [ "$b2" != "1070.00" ] \
    && lim "Lost Update / divergence (+100/-30 from 1000): expected 1070.00, got n1=$b1 n2=$b2" || bad "Unexpected 1070.00"

# 6. Simultaneous UNIQUE(email) conflict
pre="$(qn "$N2" "SELECT apply_error_count FROM pg_stat_subscription_stats WHERE subname='sub_from_node1';")"
psub "$N2" "sub_from_node1"
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9101,'u1','dup@lab',10);" >/dev/null
qn "$N2" "INSERT INTO accounts (id,owner,email,balance) VALUES (9102,'u2','dup@lab',20);" >/dev/null
qn "$N2" "ALTER SUBSCRIPTION sub_from_node1 ENABLE;" >/dev/null
post="$pre"; for _ in $(seq 1 10); do post="$(qn "$N2" "SELECT apply_error_count FROM pg_stat_subscription_stats WHERE subname='sub_from_node1';")"; [ "$post" -gt "$pre" ] && break; sleep 1; done
ul="$(docker logs --tail 35 "$N2" 2>&1 | grep -E "accounts_email_key|23505" | tail -n 1 || true)"
[ "$post" -gt "$pre" ] && [ -n "$ul" ] && lim "UNIQUE(email) conflict stalled apply ($pre->$post): $ul" || bad "UNIQUE conflict missed"
qn "$N2" "DELETE FROM accounts WHERE id=9102;" >/dev/null; skerr "$N1" "sub_from_node2"
weq "$N2" "SELECT id FROM accounts WHERE email='dup@lab';" "9101" 15 || true

# 7. DDL propagation
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS ddl_probe (id INT PRIMARY KEY, v TEXT);" >/dev/null; done; rsub
qn "$N1" "INSERT INTO ddl_probe VALUES (1,'a'),(2,'b');" >/dev/null; weq "$N2" "SELECT count(*) FROM ddl_probe;" "2" 15
qn "$N1" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null; sleep 2
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';")" = "0" ] \
    && lim "ALTER TABLE ADD COLUMN did not auto-propagate to node2" || bad "Unexpected DDL propagation"
qn "$N2" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
qn "$N1" "TRUNCATE TABLE ddl_probe;" >/dev/null
weq "$N2" "SELECT count(*) FROM ddl_probe;" "0" 15 && ok "TRUNCATE TABLE propagated to node2" || bad "TRUNCATE missed"

# 8. Feature probes
qn "$N1" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 & lp=$!; sleep 1
g2="$(qn "$N2" "SELECT pg_try_advisory_lock(4242);")"; wait "$lp" || true
[ "$g2" = "t" ] && lim "pg_advisory_lock is node-local (n2 acquired 4242: $g2)" || bad "Advisory lock unexpected"
docker exec -e PGPASSWORD="$P" "$N2" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_birep; SELECT pg_sleep(3);'" >/tmp/lb.out 2>&1 & lnp=$!; sleep 1
qn "$N1" "NOTIFY ch_birep, 'cross';" >/dev/null; wait "$lnp" || true
! grep -q "cross" /tmp/lb.out && lim "LISTEN/NOTIFY is node-local (0 cross-node events)" || bad "Unexpected NOTIFY"
rm -f /tmp/lb.out
te="$(qraw "$N1" "CREATE TEMP TABLE tmp_probe (x INT); INSERT INTO tmp_probe VALUES (1);")"
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_probe';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" \
    && ok "TEMP TABLE is session-local" || bad "TEMP TABLE unexpected"

# 9. Outage -> WAL retention -> catch-up
docker stop "$N2" >/dev/null
for k in 1 2 3 4 5; do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null; done
si="$(qn "$N1" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name='sub_from_node1';")"
sa="${si%%|*}"; wl="${si##*|}"
( [ "$sa" = "false" ] || [ "$sa" = "f" ] ) && [ "${wl:-0}" -gt 0 ] \
    && ok "Outage write OK; slot active=$sa, WAL retained=${wl}B" || bad "Slot state: $si"
docker start "$N2" >/dev/null
until docker exec -e PGPASSWORD="$P" "$N2" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
weq "$N2" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "5" 30 \
    && ok "Node2 caught up all 5 outage rows" || bad "Outage catch-up failed"

echo "=========================================================="
echo "pg-birep Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
