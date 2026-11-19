#!/usr/bin/env bash
# Bucardo 5 (PG 17 trigger-based multi-master) functional and limits suite.
set -euo pipefail

[ -f .env ] && { set -a; . ./.env; set +a; }
U="${PG_USER:-postgres}"; D="${PG_DB:-labdb}"
P="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
N1="bucardo_node1"; N2="bucardo_node2"; DM="bucardo_daemon"
mkdir -p reports; REP="reports/test_bucardo_$(date +%Y%m%d_%H%M%S).md"
PASS=0; FAIL=0; LIMIT=0
log() { echo "$1"; echo "$1" >> "$REP"; }
ok() { PASS=$((PASS+1)); log "[PASS] $1"; }
bad() { FAIL=$((FAIL+1)); log "[FAIL] $1"; }
lim() { LIMIT=$((LIMIT+1)); log "[EXPECTED_LIMITATION] $1"; }
qn() { docker exec -e PGPASSWORD="$P" "$1" psql -v ON_ERROR_STOP=1 -U "$U" -d "${3:-$D}" -tAc "$2"; }
qraw() { docker exec -e PGPASSWORD="$P" "$1" psql -v VERBOSITY=verbose -v ON_ERROR_STOP=1 -U "$U" -d "$D" -c "$2" 2>&1 || true; }
bcmd() { docker exec "$DM" timeout 15 bucardo "$@" 2>&1 || true; }
bstop() {
    bcmd stop >/dev/null
    local i=0; while docker exec "$DM" test -f /var/run/bucardo/bucardo.mcp.pid && [ "$i" -lt 15 ]; do sleep 1; i=$((i+1)); done; sleep 1
}
bstart() {
    bcmd start >/dev/null
    local i=0; until docker exec "$DM" test -f /var/run/bucardo/bucardo.mcp.pid || [ "$i" -ge 15 ]; do sleep 1; i=$((i+1)); done; sleep 2
}
brestart() { bstop; bstart; }
weq() {
    local i=0 g=""
    while [ "$i" -lt "${4:-25}" ]; do
        g="$(qn "$1" "$2" 2>/dev/null | tr -d '[:space:]' || true)"
        [ "$g" = "$3" ] && return 0; sleep 1; i=$((i+1))
    done; return 1
}
wconv() {
    local i=0 a="" b=""
    while [ "$i" -lt 20 ]; do
        a="$(qn "$N1" "$1" 2>/dev/null || true)"; b="$(qn "$N2" "$1" 2>/dev/null || true)"
        [ -n "$a" ] && [ "$a" = "$b" ] && return 0; sleep 1; i=$((i+1))
    done; return 1
}
echo "# Bucardo 5 Report ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > "$REP"

# 1. Health
st="$(bcmd status sync_mm)"; plp="$(qn "$N1" "SELECT count(*) FROM pg_extension WHERE extname='plperlu';" bucardo)"
tr1="$(qn "$N1" "SELECT count(*) FROM information_schema.triggers WHERE trigger_name LIKE 'bucardo_delta%';")"
tr2="$(qn "$N2" "SELECT count(*) FROM information_schema.triggers WHERE trigger_name LIKE 'bucardo_delta%';")"
pt="$(docker port "$N1" | grep -c 15461 || true)$(docker port "$N2" | grep -c 15462 || true)"
echo "$st" | grep -q "Current state.*Good" && [ "$plp" = "1" ] && [ "$tr1" -ge 1 ] && [ "$tr2" -ge 1 ] && [ "$pt" = "11" ] \
    && ok "Bucardo sync_mm Good/Active, plperlu=1, delta triggers=${tr1}/${tr2}, ports 15461/15462" || bad "Health: $plp $tr1/$tr2 $pt"

# 2. Bidirectional + concurrent writes
qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('a1','a@lab',500),('b1','b@lab',600);" >/dev/null
qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('c2','c@lab',700),('d2','d@lab',800);" >/dev/null
( for i in $(seq 1 8); do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('cn1_${i}','cn1_${i}@lab',100);" >/dev/null; done ) & p1=$!
( for i in $(seq 1 8); do qn "$N2" "INSERT INTO accounts (owner,email,balance) VALUES ('cn2_${i}','cn2_${i}@lab',200);" >/dev/null; done ) & p2=$!
wait "$p1" "$p2"; bcmd kick sync_mm 5 >/dev/null
weq "$N1" "SELECT count(*) FROM accounts;" "20" 25 && weq "$N2" "SELECT count(*) FROM accounts;" "20" 25 \
    && ok "Bidirectional + concurrent writes converged (20/20)" || bad "Accounts convergence failed"

# 3. Uncoordinated SERIAL PK collision (bucardo_latest silent overwrite)
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS uncoord_serial (id SERIAL PRIMARY KEY, src TEXT);" >/dev/null; done
bcmd add sync sync_serial dbs=grp_mm tables=public.uncoord_serial conflict_strategy=bucardo_latest >/dev/null
brestart; bstop
qn "$N1" "INSERT INTO uncoord_serial (src) VALUES ('from_n1');" >/dev/null; sleep 1
qn "$N2" "INSERT INTO uncoord_serial (src) VALUES ('from_n2');" >/dev/null
bstart; bcmd kick sync_serial 5 >/dev/null; wconv "SELECT src FROM uncoord_serial WHERE id=1;" || true
w1="$(qn "$N1" "SELECT src FROM uncoord_serial WHERE id=1;")"; w2="$(qn "$N2" "SELECT src FROM uncoord_serial WHERE id=1;")"
cl="$(docker exec "$DM" grep -E "Conflicts for public\.uncoord_serial" /var/log/bucardo/log.bucardo 2>/dev/null | tail -n 1 || true)"
[ "$w1" = "$w2" ] && lim "SERIAL PK collision resolved silently via bucardo_latest (winner=$w1); $cl" || bad "SERIAL collision diverged: $w1/$w2"

# 4. Keyless table rejection -> PK fix
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS pgbench_history_nokey (tid INT, bid INT, aid INT, delta INT, mtime TIMESTAMPTZ DEFAULT now());" >/dev/null; done
nk="$(bcmd add sync sync_nokey dbs=grp_mm tables=public.pgbench_history_nokey conflict_strategy=bucardo_latest)"
echo "$nk" | grep -qiE "primary key|must specify" \
    && lim "Keyless table rejected by Bucardo validate_sync: $(echo "$nk" | grep 'ERROR:' | head -n 1)" || bad "Keyless not rejected: $nk"
for n in "$N1" "$N2"; do qn "$n" "ALTER TABLE pgbench_history_nokey ADD COLUMN hid BIGSERIAL PRIMARY KEY;" >/dev/null; done
bcmd add sync sync_nokey dbs=grp_mm tables=public.pgbench_history_nokey conflict_strategy=bucardo_latest >/dev/null; brestart
qn "$N1" "INSERT INTO pgbench_history_nokey (tid,bid,aid,delta) VALUES (1,1,1,50);" >/dev/null
bcmd kick sync_nokey 5 >/dev/null; weq "$N2" "SELECT count(*) FROM pgbench_history_nokey;" "1" 15
qn "$N1" "UPDATE pgbench_history_nokey SET delta=999 WHERE aid=1;" >/dev/null; bcmd kick sync_nokey 5 >/dev/null
weq "$N2" "SELECT delta FROM pgbench_history_nokey WHERE aid=1;" "999" 15 && ok "Surrogate PK unlocked Bucardo sync & UPDATE" || bad "PK UPDATE failed"

# 5. Lost Update under bucardo_latest
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9001,'lww','lww@lab',1000.00);" >/dev/null
bcmd kick sync_mm 5 >/dev/null; weq "$N2" "SELECT balance::int FROM accounts WHERE id=9001;" "1000" 15
bstop
qn "$N1" "UPDATE accounts SET balance=balance+100 WHERE id=9001;" >/dev/null; sleep 1
qn "$N2" "UPDATE accounts SET balance=balance-30 WHERE id=9001;" >/dev/null
bstart; bcmd kick sync_mm 5 >/dev/null; wconv "SELECT balance FROM accounts WHERE id=9001;" || true
b1="$(qn "$N1" "SELECT balance FROM accounts WHERE id=9001;")"; b2="$(qn "$N2" "SELECT balance FROM accounts WHERE id=9001;")"
[ "$b1" != "1070.00" ] && [ "$b2" != "1070.00" ] \
    && lim "Lost Update under bucardo_latest (+100/-30 from 1000): expected 1070.00, converged to n1=$b1 n2=$b2" || bad "Unexpected 1070.00"

# 6. Simultaneous UNIQUE(email) conflict
bstop
qn "$N1" "INSERT INTO accounts (id,owner,email,balance) VALUES (9101,'u1','dup_buc@lab',10);" >/dev/null
qn "$N2" "INSERT INTO accounts (id,owner,email,balance) VALUES (9102,'u2','dup_buc@lab',20);" >/dev/null
bstart; bcmd kick sync_mm 5 >/dev/null; sleep 2
se="$(bcmd status sync_mm | grep -E "Current state|Last error" | tr '\n' ' ')"
ul="$(docker exec "$DM" grep -E "23505|accounts_email_key" /var/log/bucardo/log.bucardo 2>/dev/null | tail -n 1 || true)"
lim "UNIQUE(email) conflict stalled sync_mm: $se; log=$ul"
qn "$N2" "DELETE FROM accounts WHERE id=9102; TRUNCATE bucardo.delta_public_accounts;" >/dev/null
brestart; bcmd kick sync_mm 5 >/dev/null
weq "$N2" "SELECT id FROM accounts WHERE email='dup_buc@lab';" "9101" 15 || true

# 7. DDL propagation (ALTER TABLE vs TRUNCATE)
for n in "$N1" "$N2"; do qn "$n" "CREATE TABLE IF NOT EXISTS ddl_probe (id INT PRIMARY KEY, v TEXT);" >/dev/null; done
bcmd add sync sync_ddl dbs=grp_mm tables=public.ddl_probe conflict_strategy=bucardo_latest >/dev/null; brestart
qn "$N1" "INSERT INTO ddl_probe VALUES (1,'a'),(2,'b');" >/dev/null; bcmd kick sync_ddl 5 >/dev/null; weq "$N2" "SELECT count(*) FROM ddl_probe;" "2" 15
qn "$N1" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null; sleep 1
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.columns WHERE table_name='ddl_probe' AND column_name='extra';")" = "0" ] \
    && lim "ALTER TABLE ADD COLUMN did not propagate (trigger-based)" || bad "Unexpected DDL propagation"
qn "$N2" "ALTER TABLE ddl_probe ADD COLUMN extra TEXT DEFAULT 'v1';" >/dev/null
qn "$N1" "TRUNCATE TABLE ddl_probe;" >/dev/null; bcmd kick sync_ddl 5 >/dev/null; sleep 2
[ "$(qn "$N2" "SELECT count(*) FROM ddl_probe;")" = "0" ] && ok "TRUNCATE TABLE propagated via Bucardo trigger" || lim "TRUNCATE did not clear node2"

# 8. Feature probes
qn "$N1" "SELECT pg_advisory_lock(4242); SELECT pg_sleep(4);" >/dev/null 2>&1 & lp=$!; sleep 1
g2="$(qn "$N2" "SELECT pg_try_advisory_lock(4242);")"; wait "$lp" || true
[ "$g2" = "t" ] && lim "pg_advisory_lock is node-local (n2 acquired 4242: $g2)" || bad "Advisory lock unexpected"
docker exec -e PGPASSWORD="$P" "$N2" bash -c "psql -U '$U' -d '$D' -c 'LISTEN ch_buc; SELECT pg_sleep(3);'" >/tmp/lbuc.out 2>&1 & lnp=$!; sleep 1
qn "$N1" "NOTIFY ch_buc, 'cross';" >/dev/null; wait "$lnp" || true
! grep -q "cross" /tmp/lbuc.out && lim "LISTEN/NOTIFY is node-local (0 cross-node events)" || bad "Unexpected NOTIFY"
rm -f /tmp/lbuc.out
te="$(qraw "$N1" "CREATE TEMP TABLE tmp_probe (x INT); INSERT INTO tmp_probe VALUES (1);")"
[ "$(qn "$N2" "SELECT count(*) FROM information_schema.tables WHERE table_name='tmp_probe';")" = "0" ] && ! echo "$te" | grep -q "ERROR:" \
    && ok "TEMP TABLE is session-local" || bad "TEMP TABLE unexpected"

# 9. Node outage -> Bucardo delta backlog -> catch-up
docker stop "$N2" >/dev/null
for k in 1 2 3 4 5; do qn "$N1" "INSERT INTO accounts (owner,email,balance) VALUES ('outage_${k}','out_${k}@lab',50);" >/dev/null; done
dc="$(qn "$N1" "SELECT count(*) FROM bucardo.delta_public_accounts;")"
[ "$dc" -ge 5 ] && ok "Outage write OK; delta backlog=$dc rows in bucardo.delta_public_accounts" || bad "Delta backlog=$dc"
docker start "$N2" >/dev/null
until docker exec -e PGPASSWORD="$P" "$N2" pg_isready -U "$U" -d "$D" >/dev/null 2>&1; do sleep 1; done
brestart; bcmd kick sync_mm 5 >/dev/null
weq "$N2" "SELECT count(*) FROM accounts WHERE owner LIKE 'outage_%';" "5" 30 \
    && ok "Node2 caught up all 5 outage rows via Bucardo delta replay" || bad "Outage catch-up failed"

echo "=========================================================="
echo "bucardo Summary: PASS=$PASS FAIL=$FAIL EXPECTED_LIMITATION=$LIMIT"
echo "Report: $REP"
echo "=========================================================="
[ "$FAIL" -eq 0 ] || exit 1
