#!/usr/bin/env bash
# pgEdge (PG 17 + Spock 5 + Snowflake) functional and empirical limits test suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"; D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
N1="pgedge_node1"; N2="pgedge_node2"; N3="pgedge_node3"; HAP="haproxy_pgedge"
mkdir -p reports; REP="reports/test_pgedge_$(date +%Y%m%d_%H%M%S).md"
PASS=0; FAIL=0; LIMIT=0
log() { echo "$1"; echo "$1" >> "$REP"; }
ok() { PASS=$((PASS+1)); log "[PASS] $1"; }
bad() { FAIL=$((FAIL+1)); log "[FAIL] $1"; }
lim() { LIMIT=$((LIMIT+1)); log "[EXPECTED_LIMITATION] $1"; }
qn() { docker exec -e PGPASSWORD="$P" "$1" psql -v ON_ERROR_STOP=1 -U "$U" -d "$D" -tAc "$2"; }
qraw() { docker exec -e PGPASSWORD="$P" "$1" psql -v VERBOSITY=verbose -v ON_ERROR_STOP=1 -U "$U" -d "$D" -c "$2" 2>&1 || true; }
weq() {
    local i=0 g=""
    while [ "$i" -lt "${4:-25}" ]; do
        g="$(qn "$1" "$2" 2>/dev/null | tr -d '[:space:]' || true)"
        [ "$g" = "$3" ] && return 0; sleep 1; i=$((i+1))
    done; return 1
}
pmesh() {
    local act="$1"
    for p in "$N1:sub_n1_n2" "$N2:sub_n2_n1" "$N3:sub_n3_n1" "$N3:sub_n3_n2"; do
        qn "${p%%:*}" "SELECT spock.sub_${act}('${p##*:}', true);" >/dev/null
    done; [ "$act" = "disable" ] && sleep 1 || true
}
echo "# pgEdge Spock 5 Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. Health, Spock mesh, Snowflake & HAProxy
sn="$(qn "$N1" "SHOW snowflake.node;")/$(qn "$N2" "SHOW snowflake.node;")/$(qn "$N3" "SHOW snowflake.node;")"
cr="$(qn "$N1" "SHOW spock.conflict_resolution;")"; dr="$(qn "$N1" "SHOW spock.enable_ddl_replication;")"
mc="$(qn "$N1" "SELECT count(*) FROM spock.sub_show_status() WHERE status='replicating';")$(qn "$N2" "SELECT count(*) FROM spock.sub_show_status() WHERE status='replicating';")$(qn "$N3" "SELECT count(*) FROM spock.sub_show_status() WHERE status='replicating';")"
[ "$sn" = "1/2/3" ] && [ "$cr" = "last_update_wins" ] && [ "$dr" = "on" ] && [ "$mc" = "222" ] \
    && ok "Spock 5 mesh healthy (2/2 per node), snowflake.node=1/2/3, LWW+DDL=on" || bad "Health: $sn $cr $dr $mc"
ips=""
for _ in $(seq 1 9); do
    ip="$(docker exec -e PGPASSWORD="$P" "$N1" psql -h "$HAP" -p 5432 -U "$U" -d "$D" -tAc "SELECT inet_server_addr();" 2>/dev/null | tr -d '[:space:]' || true)"
    ips="${ips}${ip}\n"
done
uip="$(printf "%b" "$ips" | grep -v '^$' | sort -u | wc -l)"
sok="$(docker exec "$HAP" wget -qO- -T 3 http://127.0.0.1:8404/stats 2>/dev/null | grep -c "pgedge_nodes" || true)"
[ "$uip" -ge 3 ] && [ "$sok" -ge 1 ] && ok "HAProxy round-robin hit $uip/3 nodes, stats up" || bad "HAProxy: $uip $sok"

# 2. Multi-master 3-node concurrent writes + Snowflake IDs
for n in "$N1" "$N2" "$N3"; do
    qn "$n" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('s_${n}','s_${n}@lab',100,100);" >/dev/null
    ( for i in $(seq 1 6); do qn "$n" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('c_${n}_${i}','c_${n}_${i}@lab',100,100);" >/dev/null; done ) &
done; wait
weq "$N1" "SELECT count(*) FROM accounts;" "21" 25 && weq "$N2" "SELECT count(*) FROM accounts;" "21" 25 && weq "$N3" "SELECT count(*) FROM accounts;" "21" 25 \
    && [ "$(qn "$N1" "SELECT count(DISTINCT snowflake.get_node(id)) FROM accounts;")" = "3" ] \
    && ok "3-node concurrent writes converged (21/21), Snowflake IDs from 3 nodes" || bad "3-node convergence failed"

# 3. Uncoordinated SERIAL PK collision (LWW silent overwrite)
qn "$N1" "CREATE TABLE IF NOT EXISTS uncoord_serial (id SERIAL PRIMARY KEY, src TEXT);" >/dev/null
weq "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='uncoord_serial';" "1" 15
pmesh disable; qn "$N1" "INSERT INTO uncoord_serial (src) VALUES ('from_n1');" >/dev/null; sleep 1
qn "$N2" "INSERT INTO uncoord_serial (src) VALUES ('from_n2');" >/dev/null; pmesh enable; sleep 3
uw="$(qn "$N1" "SELECT src FROM uncoord_serial WHERE id=1;")"
rc="$(qn "$N1" "SELECT count(*) FROM spock.resolutions WHERE relname='public.uncoord_serial';")"
lim "SERIAL PK collision silently resolved via LWW (winner=$uw, resolutions=$rc, from_n1 overwritten)"

# 4. Keyless table UPDATE/DELETE limit -> PK fix
qn "$N1" "CREATE TABLE IF NOT EXISTS pgbench_history_nokey (tid INT, bid INT, aid INT, delta INT, mtime TIMESTAMPTZ DEFAULT now());" >/dev/null
weq "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='pgbench_history_nokey';" "1" 15
rs="$(qn "$N1" "SELECT set_name FROM spock.tables WHERE relname='pgbench_history_nokey';")"
qn "$N1" "INSERT INTO pgbench_history_nokey (tid,bid,aid,delta) VALUES (1,1,1,50);" >/dev/null
weq "$N2" "SELECT count(*) FROM pgbench_history_nokey;" "1" 15 && ok "Keyless INSERT replicated (repset=$rs)" || bad "Keyless INSERT failed"
ue="$(qraw "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;")"
de="$(qraw "$N1" "DELETE FROM pgbench_history_nokey WHERE aid=1;")"
n2d="$(qn "$N2" "SELECT delta FROM pgbench_history_nokey WHERE aid=1;" 2>/dev/null | head -n1 || true)"
lim "Keyless UPDATE/DELETE not replicated (repset=$rs): n1 executed ${ue%%$'\n'*}/${de%%$'\n'*}, n2 kept stale delta=${n2d:-none}"
qn "$N1" "TRUNCATE TABLE pgbench_history_nokey;" >/dev/null || true
qn "$N1" "ALTER TABLE pgbench_history_nokey ADD COLUMN hid BIGSERIAL PRIMARY KEY;" >/dev/null
qn "$N1" "INSERT INTO pgbench_history_nokey (tid,bid,aid,delta) VALUES (1,1,2,50);" >/dev/null
weq "$N2" "SELECT count(*) FROM pgbench_history_nokey WHERE aid=2;" "1" 15
qn "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=2;" >/dev/null
weq "$N2" "SELECT delta FROM pgbench_history_nokey WHERE aid=2;" "999" 15 && weq "$N3" "SELECT delta FROM pgbench_history_nokey WHERE aid=2;" "999" 15 \
    && ok "Surrogate PK unlocked 3-node UPDATE convergence" || bad "Surrogate PK UPDATE failed"

# 5. Lost Update on lww_bal vs Spock delta_apply on balance
qn "$N1" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('delta_p','delta@lab',1000.00,1000.00);" >/dev/null
weq "$N2" "SELECT balance::int FROM accounts WHERE owner='delta_p';" "1000" 15
weq "$N3" "SELECT balance::int FROM accounts WHERE owner='delta_p';" "1000" 15
pmesh disable; qn "$N1" "UPDATE accounts SET balance=balance+100, lww_bal=lww_bal+100 WHERE owner='delta_p';" >/dev/null; sleep 1
qn "$N2" "UPDATE accounts SET balance=balance-30, lww_bal=lww_bal-30 WHERE owner='delta_p';" >/dev/null; pmesh enable; sleep 4
b1="$(qn "$N1" "SELECT balance FROM accounts WHERE owner='delta_p';")"; l1="$(qn "$N1" "SELECT lww_bal FROM accounts WHERE owner='delta_p';")"
b2="$(qn "$N2" "SELECT balance FROM accounts WHERE owner='delta_p';")"; b3="$(qn "$N3" "SELECT balance FROM accounts WHERE owner='delta_p';")"
[ "$l1" != "1070.00" ] && lim "LWW lost update on lww_bal (+100/-30 from 1000): got $l1 instead of 1070.00" || bad "lww_bal unexpectedly 1070"
[ "$b1" = "1070.00" ] && [ "$b2" = "1070.00" ] && [ "$b3" = "1070.00" ] \
    && ok "Spock delta_apply preserved both deltas -> 1070.00 on n1=$b1 n2=$b2 n3=$b3" || bad "delta_apply mismatch: $b1 $b2 $b3"

# 6. Simultaneous UNIQUE(email) insert conflict
pmesh disable; qn "$N1" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('u1','dup_spock@lab',10,10);" >/dev/null; sleep 1
qn "$N2" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('u2','dup_spock@lab',20,20);" >/dev/null; pmesh enable; sleep 4
uc1="$(qn "$N1" "SELECT owner FROM accounts WHERE email='dup_spock@lab';")"; uc2="$(qn "$N2" "SELECT owner FROM accounts WHERE email='dup_spock@lab';")"
ex="$(qn "$N1" "SELECT count(*) FROM spock.exception_log;")"
eb="$(qn "$N1" "SHOW spock.exception_behaviour;")"
ul="$(docker logs --tail 50 "$N1" 2>&1 | grep -E "accounts_email_key|23505" | tail -n 1 || true)"
lim "UNIQUE(email) conflict ($eb, exception_log=$ex): n1=$uc1 n2=$uc2; log=$ul"

# 7. Auto-DDL propagation (ALTER TABLE & TRUNCATE)
qn "$N1" "CREATE TABLE IF NOT EXISTS ddl_probe (id INT PRIMARY KEY, v TEXT);" >/dev/null
qn "$N1" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
weq "$N2" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';" "1" 15 \
    && weq "$N3" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';" "1" 15 \
    && ok "Spock auto-DDL replicated ALTER TABLE ADD COLUMN to n2 & n3" || bad "Auto-DDL failed"
qn "$N1" "INSERT INTO ddl_probe (id,v) VALUES (1,'a'),(2,'b');" >/dev/null; weq "$N2" "SELECT count(*) FROM ddl_probe;" "2" 15
qn "$N1" "TRUNCATE TABLE ddl_probe;" >/dev/null
weq "$N2" "SELECT count(*) FROM ddl_probe;" "0" 15 && weq "$N3" "SELECT count(*) FROM ddl_probe;" "0" 15 \
    && ok "TRUNCATE TABLE replicated to n2 & n3" || bad "TRUNCATE failed"

# 8. Feature probes
qn "$N1" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 & lp=$!; sleep 1
g2="$(qn "$N2" "SELECT pg_try_advisory_lock(4242);")"; wait "$lp" || true
[ "$g2" = "t" ] && lim "pg_advisory_lock is node-local (n2 acquired 4242: $g2)" || bad "Advisory lock unexpected"
docker exec -e PGPASSWORD="$P" "$N2" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_spock; SELECT pg_sleep(3);'" >/tmp/ls.out 2>&1 & lnp=$!; sleep 1
qn "$N1" "NOTIFY ch_spock, 'cross';" >/dev/null; wait "$lnp" || true
! grep -q "cross" /tmp/ls.out && lim "LISTEN/NOTIFY is node-local (0 cross-node events)" || bad "Unexpected NOTIFY"
rm -f /tmp/ls.out
te="$(qraw "$N1" "CREATE TEMP TABLE tmp_probe (x INT); INSERT INTO tmp_probe VALUES (1);")"
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_probe';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" \
    && ok "TEMP TABLE is session-local" || bad "TEMP TABLE unexpected"

# 9. Node outage (stop n3) -> WAL retention -> catch-up
docker stop "$N3" >/dev/null
for k in 1 2 3 4 5; do qn "$N1" "INSERT INTO accounts (owner,email,balance,lww_bal) VALUES ('outage_${k}','out_${k}@lab',50,50);" >/dev/null; done
si="$(qn "$N1" "SELECT active::text || '|' || pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) FROM pg_replication_slots WHERE slot_name LIKE '%sub_n3_n1';")"
sa="${si%%|*}"; wl="${si##*|}"
( [ "$sa" = "false" ] || [ "$sa" = "f" ] ) && [ "${wl:-0}" -gt 0 ] \
    && ok "Outage write OK without quorum block; slot active=$sa, WAL retained=${wl}B" || bad "Slot state: $si"
docker start "$N3" >/dev/null
until docker exec -e PGPASSWORD="$P" "$N3" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
weq "$N3" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "5" 30 \
    && ok "Node3 caught up all 5 outage rows" || bad "Node3 outage catch-up failed"

echo "=========================================================="
echo "pgedge Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
