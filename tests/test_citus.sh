#!/bin/bash
# test_citus.sh - Functional and empirical limits suite for Citus 14.2 (PG 17)
set -euo pipefail
[ -f .env ] && { set -a; . ./.env; set +a; }
PG_PASS="${PG_LAB_PASSWORD:-${DB_ROOT_PASSWORD:-pg_poc_ephemeral}}"
DB="${CITUS_DB:-labdb}"

ep() {
    local ip; ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null || true)
    if [ -n "$ip" ] && timeout 1 bash -c "</dev/tcp/$ip/5432" 2>/dev/null; then echo "$ip:5432"; else echo "127.0.0.1:$2"; fi
}
C=$(ep citus_coord 15490); CH="${C%:*}"; CP="${C#*:}"
W1=$(ep citus_worker1 15491); W1H="${W1%:*}"; W1P="${W1#*:}"
W2=$(ep citus_worker2 15492); W2H="${W2%:*}"; W2P="${W2#*:}"

mkdir -p ./reports; TS=$(date +"%Y%m%d_%H%M%S")
RMD="./reports/test_citus_${TS}.md"; RHTML="./reports/test_citus_${TS}.html"
PASS=0; FAIL=0
printf "# Citus Cluster Test Report\nDate: %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$RMD"
rec() {
    [ "$1" = "PASS" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
    echo "[$1] $2 - $3"
    printf -- "- [%s] **%s**: %s\n" "$1" "$2" "$3" >> "$RMD"
}
rsql() { PGPASSWORD="$PG_PASS" psql -h "$1" -p "$2" -U postgres -d "$DB" -tAc "$3"; }

echo "=== Citus Functional & Empirical Limits Suite ==="
VER=$(rsql "$CH" "$CP" "SELECT split_part(citus_version(),' ',2);")
WKS=$(rsql "$CH" "$CP" "SELECT count(*) FROM pg_dist_node WHERE isactive AND shouldhaveshards;")
[ "$WKS" -eq 2 ] && rec "PASS" "Cluster Membership" "Citus=$VER active_workers=$WKS" || rec "FAIL" "Cluster Membership" "workers=$WKS"

PY_OUT=$(python3 - "$CH" "$CP" "$W1H" "$W1P" "$W2H" "$W2P" "$DB" "$PG_PASS" <<'PY'
import sys, time, threading, concurrent.futures as cf, psycopg as pg
ch, cp, w1h, w1p, w2h, w2p, db, pw = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]), sys.argv[7], sys.argv[8]
cx = lambda h, p, ac=True: pg.connect(f"host={h} port={p} dbname={db} user=postgres password={pw}", autocommit=ac)
res = lambda ok, nm, dt: print(f"{'PASS' if ok else 'FAIL'}|{nm}|{dt}")

with cx(ch, cp) as c:
    for s in (
        "DROP TABLE IF EXISTS citus_accounts, citus_currencies, citus_events, pgbench_history_nokey, pgbench_history_pk, ddl_sp_test CASCADE;",
        "CREATE TABLE citus_accounts (tenant_id int, id int, balance int, email text, PRIMARY KEY(tenant_id, id)); SELECT create_distributed_table('citus_accounts','tenant_id');",
        "CREATE TABLE citus_currencies (code text PRIMARY KEY, rate numeric); SELECT create_reference_table('citus_currencies');",
        "INSERT INTO citus_currencies VALUES ('EUR',1.00),('USD',1.08);",
        "INSERT INTO citus_accounts SELECT g,1,1000,'u'||g||'@t.io' FROM generate_series(1,20) g;",
    ): c.execute(s)
    sn = c.execute("SELECT count(DISTINCT p.groupid) FROM pg_dist_shard s JOIN pg_dist_placement p ON s.shardid=p.shardid WHERE s.logicalrelid='citus_accounts'::regclass;").fetchone()[0]
with cx(w1h, w1p) as w1, cx(w2h, w2p) as w2:
    r1, r2 = w1.execute("SELECT count(*) FROM citus_currencies;").fetchone()[0], w2.execute("SELECT count(*) FROM citus_currencies;").fetchone()[0]
res(sn == 2 and r1 == 2 and r2 == 2, "Distributed & Reference Writes", f"shards_workers={sn} ref_w1={r1} ref_w2={r2}")

with cx(ch, cp) as c:
    c.execute("CREATE TABLE citus_events (id bigserial PRIMARY KEY, payload text); SELECT create_distributed_table('citus_events','id');")
    t0 = time.perf_counter()
    for i in range(50): c.execute("INSERT INTO citus_events (payload) VALUES (%s);", (f"ev-{i}",))
    ms = (time.perf_counter() - t0) * 1000.0
    cnt, mn, mx = c.execute("SELECT count(*),min(id),max(id) FROM citus_events;").fetchone()
res(cnt == 50, "Sequence & Latency", f"count={cnt} min={mn} max={mx} avg_ms={ms/50:.2f}")

def upd(_):
    with cx(ch, cp, False) as cn: cn.execute("UPDATE citus_accounts SET balance=balance+10 WHERE tenant_id=1 AND id=1;"); cn.commit()
with cf.ThreadPoolExecutor(max_workers=10) as ex: list(ex.map(upd, range(10)))
with cx(ch, cp) as c: bal = c.execute("SELECT balance FROM citus_accounts WHERE tenant_id=1 AND id=1;").fetchone()[0]
rr_err = []
c1, c2 = cx(ch, cp, False), cx(ch, cp, False)
for k in (c1, c2): k.execute("BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT balance FROM citus_accounts WHERE tenant_id=1 AND id=1;")
c1.execute("UPDATE citus_accounts SET balance=balance+5 WHERE tenant_id=1 AND id=1;")
def rc2():
    try: c2.execute("UPDATE citus_accounts SET balance=balance+5 WHERE tenant_id=1 AND id=1;"); c2.commit()
    except Exception as e: rr_err.append(f"{getattr(e,'sqlstate','ERR')}:{str(e).splitlines()[0]}"); c2.rollback()
t = threading.Thread(target=rc2); t.start(); c1.commit(); t.join(); c1.close(); c2.close()
res(bal == 1100 and any("40001" in e for e in rr_err), "Concurrent Same-Row Update", f"RC_bal={bal} RR_40001={rr_err}")

with cx(ch, cp) as c:
    try: c.execute("CREATE UNIQUE INDEX idx_bad_email ON citus_accounts(email);"); umsg = "OK"
    except Exception as e: umsg = f"{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}"
    c.execute("CREATE UNIQUE INDEX idx_good_te ON citus_accounts(tenant_id, email);")
res("0A000" in umsg, "Unique Constraint Limit (0A000)", f"{umsg}; with_dist_key=OK")

with cx(ch, cp) as c:
    c.execute("CREATE TABLE pgbench_history_nokey (tid int, bid int, aid int, delta int, mtime timestamp, filler char(22)); SELECT create_distributed_table('pgbench_history_nokey','aid'); INSERT INTO pgbench_history_nokey VALUES (1,1,10,50,now(),'a');")
    errs = []
    for sql in ("ALTER TABLE pgbench_history_nokey ADD PRIMARY KEY (tid);", "ALTER TABLE pgbench_history_nokey ADD COLUMN sk bigserial;"):
        try: c.execute(sql)
        except Exception as e: errs.append(f"{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}")
    c.execute("CREATE TABLE pgbench_history_pk (tid int, bid int, aid int, delta int, mtime timestamp, sk bigserial, PRIMARY KEY(aid, sk)); SELECT create_distributed_table('pgbench_history_pk','aid'); INSERT INTO pgbench_history_pk (tid,bid,aid,delta,mtime) VALUES (1,1,10,50,now());")
    kc = c.execute("SELECT count(*) FROM pgbench_history_pk;").fetchone()[0]
res(len(errs) == 2 and kc == 1, "Keyless Table & Surrogate PK", f"limits={errs} upfront_pk_rows={kc}")

with cx(ch, cp, False) as c:
    c.execute("ALTER TABLE citus_accounts ADD COLUMN IF NOT EXISTS note text DEFAULT 'ok';"); c.commit()
    c.execute("BEGIN; CREATE TABLE ddl_sp_test (id int PRIMARY KEY, v text); SELECT create_distributed_table('ddl_sp_test','id'); SAVEPOINT sp1; INSERT INTO ddl_sp_test VALUES (1,'drop'); ROLLBACK TO SAVEPOINT sp1; INSERT INTO ddl_sp_test VALUES (2,'keep'); COMMIT;")
    rows = c.execute("SELECT id, v FROM ddl_sp_test;").fetchall(); c.execute("DROP TABLE ddl_sp_test;"); c.commit()
with cx(w1h, w1p) as w1:
    wcol = w1.execute("SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid WHERE c.relname LIKE 'citus_accounts%' AND a.attname='note' AND NOT a.attisdropped;").fetchone()[0]
res(wcol >= 1 and rows == [(2, 'keep')], "DDL Propagation & SAVEPOINT", f"worker_shard_cols={wcol} tx_ddl_savepoint={rows}")

with cx(ch, cp) as c:
    adv = c.execute("SELECT pg_try_advisory_lock(42);").fetchone()[0]; c.execute("SELECT pg_advisory_unlock(42);")
    c.execute("LISTEN citus_ch; NOTIFY citus_ch, 'ping';"); notif = [n.payload for n in c.notifies(timeout=0.5, stop_after=1)]
    c.execute("CREATE TEMP TABLE tmp_probe (id int); INSERT INTO tmp_probe VALUES (99);"); tc = c.execute("SELECT count(*) FROM tmp_probe;").fetchone()[0]
    exts = []
    for ext in ("pg_trgm", "uuid-ossp", "vector"):
        try: c.execute(f'CREATE EXTENSION IF NOT EXISTS "{ext}";'); exts.append(f"{ext}=OK")
        except Exception as e: exts.append(f"{ext}=ERR({getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]})")
res(adv and tc == 1 and "pg_trgm=OK" in exts, "PG Features & Extensions", f"adv={adv} notify={notif} temp={tc} {' '.join(exts)}")
PY
)
while IFS='|' read -r st nm dt; do [ -n "$st" ] && rec "$st" "$nm" "$dt"; done <<< "$PY_OUT"

TW1=$(rsql "$CH" "$CP" "SELECT t FROM generate_series(1,20) t WHERE get_shard_id_for_distribution_column('citus_accounts',t) IN (SELECT s.shardid FROM pg_dist_shard s JOIN pg_dist_placement p ON s.shardid=p.shardid JOIN pg_dist_node n ON p.groupid=n.groupid WHERE s.logicalrelid='citus_accounts'::regclass AND n.nodename='citus_worker1') LIMIT 1;")
TW2=$(rsql "$CH" "$CP" "SELECT t FROM generate_series(1,20) t WHERE get_shard_id_for_distribution_column('citus_accounts',t) IN (SELECT s.shardid FROM pg_dist_shard s JOIN pg_dist_placement p ON s.shardid=p.shardid JOIN pg_dist_node n ON p.groupid=n.groupid WHERE s.logicalrelid='citus_accounts'::regclass AND n.nodename='citus_worker2') LIMIT 1;")

docker stop citus_worker2 >/dev/null
REF_UP=$(rsql "$CH" "$CP" "SELECT count(*) FROM citus_currencies;")
W1_OK=$(rsql "$CH" "$CP" "SELECT balance FROM citus_accounts WHERE tenant_id=$TW1 AND id=1;")
W2_ERR=$(PGPASSWORD="$PG_PASS" psql -h "$CH" -p "$CP" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -c "SELECT balance FROM citus_accounts WHERE tenant_id=$TW2 AND id=1;" 2>&1 || true)
W2_LINE=$(echo "$W2_ERR" | grep -E "ERROR:|FATAL:" | head -n 1 || echo "$W2_ERR" | head -n 1)

docker start citus_worker2 >/dev/null
for _ in $(seq 1 30); do docker exec citus_worker2 pg_isready -U postgres -d "$DB" >/dev/null 2>&1 && break; sleep 1; done
REC_BAL=$(rsql "$CH" "$CP" "SELECT balance FROM citus_accounts WHERE tenant_id=$TW2 AND id=1;")
if [ "$REF_UP" = "2" ] && [ -n "$W1_OK" ] && echo "$W2_ERR" | grep -qi "ERROR\|connection" && [ "$REC_BAL" = "1000" ]; then
    rec "PASS" "Worker Outage & Recovery" "ref_reads=$REF_UP healthy_w1_bal=$W1_OK stopped_w2_err=\"$W2_LINE\" recovered_w2_bal=$REC_BAL"
else
    rec "FAIL" "Worker Outage & Recovery" "ref=$REF_UP w1=$W1_OK err=$W2_LINE rec=$REC_BAL"
fi

TOT=$((PASS + FAIL))
printf "\n## Summary\n- Passed: %s / %s\n- Failed: %s / %s\n" "$PASS" "$TOT" "$FAIL" "$TOT" >> "$RMD"
printf '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Citus Report</title></head><body><h1>Citus Cluster Test Report</h1><pre>%s</pre></body></html>\n' "$(cat "$RMD")" > "$RHTML"
echo "=== Citus Summary: Passed=$PASS Failed=$FAIL (Report: $RMD) ==="
[ "$FAIL" -eq 0 ] || exit 1
