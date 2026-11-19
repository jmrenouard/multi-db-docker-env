#!/bin/bash
# test_yugabyte.sh - Functional and empirical limits suite for YugabyteDB 2026.1
set -euo pipefail
DB="${YB_DB:-labdb}"

ep() {
    local ip; ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null || true)
    if [ -n "$ip" ] && timeout 1 bash -c "</dev/tcp/$ip/$2" 2>/dev/null; then echo "$ip:$2"; else echo "127.0.0.1:$3"; fi
}
N1=$(ep yb_node1 5433 15471); H1="${N1%:*}"; P1="${N1#*:}"
N2=$(ep yb_node2 5433 15472); H2="${N2%:*}"; P2="${N2#*:}"
N3=$(ep yb_node3 5433 15473); H3="${N3%:*}"; P3="${N3#*:}"
UI=$(ep yb_node1 7000 17001)

mkdir -p ./reports; TS=$(date +"%Y%m%d_%H%M%S")
RMD="./reports/test_yugabyte_${TS}.md"; RHTML="./reports/test_yugabyte_${TS}.html"
PASS=0; FAIL=0
printf "# YugabyteDB Cluster Test Report\nDate: %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$RMD"
rec() {
    [ "$1" = "PASS" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
    echo "[$1] $2 - $3"
    printf -- "- [%s] **%s**: %s\n" "$1" "$2" "$3" >> "$RMD"
}

echo "=== YugabyteDB Functional & Empirical Limits Suite ==="
RF=$(docker exec yb_node1 /home/yugabyte/bin/yb-admin -master_addresses yb-node1:7100,yb-node2:7100,yb-node3:7100 get_universe_config 2>/dev/null | grep -oE '"numReplicas":[0-9]+' | head -n 1 | cut -d: -f2 || echo "0")

PY_OUT=$(python3 - "$H1" "$P1" "$H2" "$P2" "$H3" "$P3" "$UI" "$DB" "$RF" <<'PY'
import sys, time, random, urllib.request as ur, concurrent.futures as cf, psycopg as pg
h1, p1, h2, p2, h3, p3, ui, db, rf = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]), sys.argv[7], sys.argv[8], sys.argv[9]
cx = lambda h, p, ac=True, tm=5: pg.connect(f"host={h} port={p} dbname={db} user=yugabyte sslmode=disable", connect_timeout=tm, autocommit=ac)
res = lambda ok, nm, dt: print(f"{'PASS' if ok else 'FAIL'}|{nm}|{dt}")

with cx(h1, p1) as c:
    ver = c.execute("SELECT version();").fetchone()[0].split(" on ")[0]
    iso = c.execute("SHOW default_transaction_isolation;").fetchone()[0]
    srv = c.execute("SELECT count(*) FROM yb_servers();").fetchone()[0]
with ur.urlopen(f"http://{ui}/", timeout=5) as r: uic = r.status
res(srv == 3 and rf == "3" and uic == 200, "Cluster Health & Raft RF=3", f"{ver} srv={srv} rf={rf} iso={iso} ui={uic}")

with cx(h1, p1) as c1, cx(h2, p2) as c2, cx(h3, p3) as c3:
    c1.execute("DROP TABLE IF EXISTS yb_accounts, yb_seq_c1, yb_seq_c100, pgbench_history_nokey, pgbench_history_pk, yb_tx_ddl;")
    c1.execute("CREATE TABLE yb_accounts (id INT PRIMARY KEY, balance INT NOT NULL, email TEXT UNIQUE NOT NULL);")
    c1.execute("INSERT INTO yb_accounts VALUES (1,1000,'a1@t.io');"); c2.execute("INSERT INTO yb_accounts VALUES (2,2000,'a2@t.io');")
    rows = c3.execute("SELECT id, balance FROM yb_accounts ORDER BY id;").fetchall()
res(rows == [(1, 1000), (2, 2000)], "Multi-Node Active-Active Writes", f"rows={rows}")

with cx(h1, p1) as c:
    c.execute("CREATE SEQUENCE yb_s1 CACHE 1; CREATE TABLE yb_seq_c1 (id BIGINT DEFAULT nextval('yb_s1') PRIMARY KEY, v INT);")
    t0 = time.perf_counter()
    for i in range(50): c.execute("INSERT INTO yb_seq_c1 (v) VALUES (%s);", (i,))
    ms1 = (time.perf_counter() - t0) * 1000.0
    c.execute("CREATE SEQUENCE yb_s100 CACHE 100; CREATE TABLE yb_seq_c100 (id BIGINT DEFAULT nextval('yb_s100') PRIMARY KEY, v INT);")
    t0 = time.perf_counter()
    for i in range(50): c.execute("INSERT INTO yb_seq_c100 (v) VALUES (%s);", (i,))
    ms100 = (time.perf_counter() - t0) * 1000.0
    c1, c100 = c.execute("SELECT count(*) FROM yb_seq_c1;").fetchone()[0], c.execute("SELECT count(*) FROM yb_seq_c100;").fetchone()[0]
res(c1 == 50 and c100 == 50, "Sequence & Latency", f"cache1={ms1/50:.2f}ms cache100={ms100/50:.2f}ms")

def raw_u(tid):
    with cx(h1 if tid%2==0 else h2, p1 if tid%2==0 else p2, False) as cn:
        cn.execute("BEGIN ISOLATION LEVEL REPEATABLE READ;")
        b = cn.execute("SELECT balance FROM yb_accounts WHERE id=1;").fetchone()[0]
        time.sleep(0.03); cn.execute("UPDATE yb_accounts SET balance=%s WHERE id=1;", (b+10,)); cn.commit()
raw_errs = []
def try_raw(tid):
    try: raw_u(tid)
    except Exception as e: raw_errs.append(f"{getattr(e,'sqlstate','ERR')}:{str(e).splitlines()[0]}")
with cf.ThreadPoolExecutor(max_workers=10) as ex: list(ex.map(try_raw, range(10)))
with cx(h1, p1) as c: c.execute("UPDATE yb_accounts SET balance=1000 WHERE id=1;")

retries = [0]
def ret_u(tid):
    for _ in range(30):
        try:
            with cx(h1 if tid%2==0 else h2, p1 if tid%2==0 else p2, False) as cn:
                cn.execute("BEGIN ISOLATION LEVEL REPEATABLE READ;")
                b = cn.execute("SELECT balance FROM yb_accounts WHERE id=1;").fetchone()[0]
                time.sleep(0.01); cn.execute("UPDATE yb_accounts SET balance=%s WHERE id=1;", (b+10,)); cn.commit(); return
        except Exception as e:
            if getattr(e, "sqlstate", "") == "40001": retries[0] += 1; time.sleep(0.01*(1+random.random())); continue
            raise
with cf.ThreadPoolExecutor(max_workers=10) as ex: list(ex.map(ret_u, range(10)))
with cx(h3, p3, False) as c3: bal = c3.execute("SELECT balance FROM yb_accounts WHERE id=1;").fetchone()[0]
res(bal == 1100 and any("40001" in e for e in raw_errs), "Same-Row Conflict & 40001 Retry", f"no_retry_40001={len(raw_errs)} sample={raw_errs[:1]} retry_bal={bal} retries={retries[0]}")

with cx(h2, p2) as c2:
    try: c2.execute("INSERT INTO yb_accounts VALUES (99, 10, 'a1@t.io');"); uerr = "OK"
    except Exception as e: uerr = f"{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}"
res("23505" in uerr, "Secondary UNIQUE Enforcement", uerr)

with cx(h1, p1) as c:
    c.execute("CREATE TABLE pgbench_history_nokey (tid int, bid int, aid int, delta int, mtime timestamp, filler char(22)); INSERT INTO pgbench_history_nokey VALUES (1,1,1,50,now(),'a');")
    nk = c.execute("SELECT count(*) FROM pgbench_history_nokey;").fetchone()[0]
    c.execute("CREATE TABLE pgbench_history_pk (tid int, bid int, aid int, delta int, mtime timestamp, sk bigserial PRIMARY KEY); INSERT INTO pgbench_history_pk (tid,bid,aid,delta,mtime) VALUES (1,1,1,50,now());")
    pkc = c.execute("SELECT count(*) FROM pgbench_history_pk;").fetchone()[0]
res(nk == 1 and pkc == 1, "Keyless Table & Surrogate PK", f"nokey_rows={nk} surrogate_pk_rows={pkc}")

with cx(h1, p1) as c1, cx(h3, p3) as c3:
    c1.execute("ALTER TABLE yb_accounts ADD COLUMN tag TEXT DEFAULT 'ok';")
    htag = c3.execute("SELECT count(*) FROM information_schema.columns WHERE table_name='yb_accounts' AND column_name='tag';").fetchone()[0]
with cx(h1, p1, False) as c:
    try:
        c.execute("CREATE TABLE yb_tx_ddl (id int PRIMARY KEY); SAVEPOINT sp1; INSERT INTO yb_tx_ddl VALUES (1); ROLLBACK TO SAVEPOINT sp1; INSERT INTO yb_tx_ddl VALUES (2);")
        c.commit(); ddl_sp = f"OK:{c.execute('SELECT id FROM yb_tx_ddl;').fetchall()}"
    except Exception as e: ddl_sp = f"LIMIT:{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}"; c.rollback()
res(htag == 1, "DDL Propagation & SAVEPOINT", f"node3_col={htag} tx_ddl_savepoint={ddl_sp}")

with cx(h1, p1) as c:
    pr = []
    for lbl, sql in (
        ("temp", "CREATE TEMP TABLE tmp_p (id int); INSERT INTO tmp_p VALUES (1);"),
        ("adv_lock", "SELECT pg_try_advisory_lock(42);"),
        ("listen", "LISTEN yb_ch;"),
        ("pg_trgm", "CREATE EXTENSION IF NOT EXISTS pg_trgm;"),
        ("uuid_ossp", 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'),
        ("vector", "CREATE EXTENSION IF NOT EXISTS vector;"),
    ):
        try: c.execute(sql); pr.append(f"{lbl}=OK")
        except Exception as e: pr.append(f"{lbl}=ERR({getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]})")
res("temp=OK" in pr and "pg_trgm=OK" in pr, "PG Features & Extensions", " ".join(pr))
PY
)
while IFS='|' read -r st nm dt; do [ -n "$st" ] && rec "$st" "$nm" "$dt"; done <<< "$PY_OUT"

run_py() { python3 -c "import sys,time,signal,psycopg as pg; d=lambda h,p: f'host={h} port={p} dbname=$DB user=yugabyte sslmode=disable'; $1"; }

docker stop yb_node2 >/dev/null
Q1_OK=$(run_py "
signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('alarm')))
for _ in range(8):
  try:
    signal.alarm(8)
    with pg.connect(d('$H1',$P1),connect_timeout=4,autocommit=True) as c1: c1.execute(\"INSERT INTO yb_accounts (id,balance,email) VALUES (101,500,'q1@t.io') ON CONFLICT (id) DO NOTHING;\")
    with pg.connect(d('$H3',$P3),connect_timeout=4,autocommit=True) as c3: print(c3.execute('SELECT balance FROM yb_accounts WHERE id=101;').fetchone()[0]); signal.alarm(0); sys.exit(0)
  except Exception: signal.alarm(0); time.sleep(2)
print('FAIL')")

docker stop yb_node3 >/dev/null
Q2_ERR=$(run_py "
def alm(*_): raise TimeoutError('quorum_lost_2_of_3_down')
signal.signal(signal.SIGALRM, alm); signal.alarm(6)
try:
  with pg.connect(d('$H1',$P1),connect_timeout=3,autocommit=True) as c1:
    c1.execute(\"SET statement_timeout='4000';\"); c1.execute(\"INSERT INTO yb_accounts (id,balance,email) VALUES (102,500,'q2@t.io');\"); print('UNEXPECTED_OK')
except Exception as e: print(f\"HALTED({getattr(e,'sqlstate','TIMEOUT')}:{str(e).splitlines()[0]})\")
finally: signal.alarm(0)")

docker start yb_node2 yb_node3 >/dev/null
for _ in $(seq 1 60); do
    SRV=$(timeout 4 docker exec yb_node2 /home/yugabyte/bin/ysqlsh -h yb-node2 -p 5433 -U yugabyte -d "$DB" -tAc "SELECT count(*) FROM yb_servers();" 2>/dev/null || echo "0")
    [ "${SRV:-0}" = "3" ] && break; sleep 2
done
sleep 5
REC_OK=$(run_py "
for _ in range(10):
  try:
    with pg.connect(d('$H2',$P2),connect_timeout=5,autocommit=True) as c:
      c.execute(\"INSERT INTO yb_accounts (id,balance,email) VALUES (103,700,'q3@t.io') ON CONFLICT (id) DO NOTHING;\"); print(c.execute('SELECT count(*) FROM yb_accounts WHERE id IN (101,103);').fetchone()[0]); sys.exit(0)
  except Exception: time.sleep(2)
print('0')")
if [ "$Q1_OK" = "500" ] && echo "$Q2_ERR" | grep -q "HALTED" && [ "$REC_OK" = "2" ]; then
    rec "PASS" "Quorum 1-Down / 2-Down Halt & Recovery" "1_down_RPO0_bal=$Q1_OK 2_down=$Q2_ERR recovered_rows=$REC_OK"
else
    rec "FAIL" "Quorum 1-Down / 2-Down Halt & Recovery" "q1=$Q1_OK q2=$Q2_ERR rec=$REC_OK"
fi

TOT=$((PASS + FAIL))
printf "\n## Summary\n- Passed: %s / %s\n- Failed: %s / %s\n" "$PASS" "$TOT" "$FAIL" "$TOT" >> "$RMD"
printf '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>YugabyteDB Report</title></head><body><h1>YugabyteDB Cluster Test Report</h1><pre>%s</pre></body></html>\n' "$(cat "$RMD")" > "$RHTML"
echo "=== YugabyteDB Summary: Passed=$PASS Failed=$FAIL (Report: $RMD) ==="
[ "$FAIL" -eq 0 ] || exit 1
