#!/bin/bash
# test_cockroach.sh - Functional and empirical limits suite for CockroachDB v24.3.0
set -euo pipefail
DB="${CRDB_DB:-labdb}"

ep() {
    local ip; ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null || true)
    if [ -n "$ip" ] && timeout 1 bash -c "</dev/tcp/$ip/$2" 2>/dev/null; then echo "$ip:$2"; else echo "127.0.0.1:$3"; fi
}
N1=$(ep crdb_node1 26257 15481); H1="${N1%:*}"; P1="${N1#*:}"
N2=$(ep crdb_node2 26257 15482); H2="${N2%:*}"; P2="${N2#*:}"
N3=$(ep crdb_node3 26257 15483); H3="${N3%:*}"; P3="${N3#*:}"
UI=$(ep crdb_node1 8080 18081)

mkdir -p ./reports; TS=$(date +"%Y%m%d_%H%M%S")
RMD="./reports/test_cockroach_${TS}.md"; RHTML="./reports/test_cockroach_${TS}.html"
PASS=0; FAIL=0
printf "# CockroachDB Cluster Test Report\nDate: %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$RMD"
rec() {
    [ "$1" = "PASS" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
    echo "[$1] $2 - $3"
    printf -- "- [%s] **%s**: %s\n" "$1" "$2" "$3" >> "$RMD"
}

echo "=== CockroachDB Functional & Empirical Limits Suite ==="
PY_OUT=$(python3 - "$H1" "$P1" "$H2" "$P2" "$H3" "$P3" "$UI" "$DB" <<'PY'
import sys, time, random, urllib.request as ur, concurrent.futures as cf, psycopg as pg
h1, p1, h2, p2, h3, p3, ui, db = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]), sys.argv[7], sys.argv[8]
cx = lambda h, p, ac=True, tm=5: pg.connect(f"host={h} port={p} dbname={db} user=root sslmode=disable", connect_timeout=tm, autocommit=ac)
res = lambda ok, nm, dt: print(f"{'PASS' if ok else 'FAIL'}|{nm}|{dt}")

with cx(h1, p1) as c:
    ver = c.execute("SELECT version();").fetchone()[0].split(" on ")[0]
    live = c.execute("SELECT count(*) FROM crdb_internal.gossip_nodes WHERE is_live;").fetchone()[0]
    rf3 = any("num_replicas = 3" in str(r) for r in c.execute("SHOW ZONE CONFIGURATION FROM RANGE default;").fetchall())
with ur.urlopen(f"http://{ui}/health?ready=1", timeout=5) as r: uic = r.status
res(live == 3 and rf3 and uic == 200, "Cluster Health & Raft RF=3", f"{ver} live={live} rf3={rf3} ui={uic}")

with cx(h1, p1) as c1, cx(h2, p2) as c2, cx(h3, p3) as c3:
    c1.execute("DROP TABLE IF EXISTS crdb_accounts, crdb_seq_ur, crdb_seq_c1, pgbench_history_nokey, pgbench_history_pk, crdb_tx_ddl, vec_probe;")
    c1.execute("CREATE TABLE crdb_accounts (id INT PRIMARY KEY, balance INT NOT NULL, email TEXT UNIQUE NOT NULL);")
    c1.execute("INSERT INTO crdb_accounts VALUES (1, 1000, 'a1@t.io');")
    c2.execute("INSERT INTO crdb_accounts VALUES (2, 2000, 'a2@t.io');")
    rows = c3.execute("SELECT id, balance FROM crdb_accounts ORDER BY id;").fetchall()
res(rows == [(1, 1000), (2, 2000)], "Multi-Node Active-Active Writes", f"rows={rows}")

with cx(h1, p1) as c:
    c.execute("CREATE TABLE crdb_seq_ur (id INT8 DEFAULT unique_rowid() PRIMARY KEY, v INT);")
    t0 = time.perf_counter()
    for i in range(50): c.execute("INSERT INTO crdb_seq_ur (v) VALUES (%s);", (i,))
    ums = (time.perf_counter() - t0) * 1000.0
    c.execute("CREATE SEQUENCE crdb_seq CACHE 1; CREATE TABLE crdb_seq_c1 (id INT8 DEFAULT nextval('crdb_seq') PRIMARY KEY, v INT);")
    t0 = time.perf_counter()
    for i in range(50): c.execute("INSERT INTO crdb_seq_c1 (v) VALUES (%s);", (i,))
    sms = (time.perf_counter() - t0) * 1000.0
    uc, sc = c.execute("SELECT count(*) FROM crdb_seq_ur;").fetchone()[0], c.execute("SELECT count(*) FROM crdb_seq_c1;").fetchone()[0]
res(uc == 50 and sc == 50, "Sequence & ID Latency", f"unique_rowid={ums/50:.2f}ms seq_cache1={sms/50:.2f}ms")

def raw_u(tid):
    with cx(h1 if tid%2==0 else h2, p1 if tid%2==0 else p2, False) as cn:
        b = cn.execute("SELECT balance FROM crdb_accounts WHERE id=1;").fetchone()[0]
        time.sleep(0.03); cn.execute("UPDATE crdb_accounts SET balance=%s WHERE id=1;", (b+10,)); cn.commit()
raw_errs = []
def try_raw(tid):
    try: raw_u(tid)
    except Exception as e: raw_errs.append(f"{getattr(e,'sqlstate','ERR')}:{str(e).splitlines()[0]}")
with cf.ThreadPoolExecutor(max_workers=10) as ex: list(ex.map(try_raw, range(10)))
with cx(h1, p1) as c: c.execute("UPDATE crdb_accounts SET balance=1000 WHERE id=1;")

retries = [0]
def ret_u(tid):
    for _ in range(30):
        try:
            with cx(h1 if tid%2==0 else h2, p1 if tid%2==0 else p2, False) as cn:
                b = cn.execute("SELECT balance FROM crdb_accounts WHERE id=1;").fetchone()[0]
                time.sleep(0.01); cn.execute("UPDATE crdb_accounts SET balance=%s WHERE id=1;", (b+10,)); cn.commit(); return
        except Exception as e:
            if getattr(e, "sqlstate", "") == "40001": retries[0] += 1; time.sleep(0.01*(1+random.random())); continue
            raise
with cf.ThreadPoolExecutor(max_workers=10) as ex: list(ex.map(ret_u, range(10)))
with cx(h3, p3, False) as c3: bal = c3.execute("SELECT balance FROM crdb_accounts WHERE id=1;").fetchone()[0]
res(bal == 1100 and any("40001" in e for e in raw_errs), "Same-Row Conflict & 40001 Retry", f"no_retry_40001={len(raw_errs)} sample={raw_errs[:1]} retry_bal={bal} retries={retries[0]}")

with cx(h2, p2) as c2:
    try: c2.execute("INSERT INTO crdb_accounts VALUES (99, 10, 'a1@t.io');"); uerr = "OK"
    except Exception as e: uerr = f"{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}"
res("23505" in uerr, "Secondary UNIQUE Enforcement", uerr)

with cx(h1, p1) as c:
    c.execute("CREATE TABLE pgbench_history_nokey (tid int, bid int, aid int, delta int, mtime timestamp, filler char(22));")
    cols = [r[0] for r in c.execute("SHOW COLUMNS FROM pgbench_history_nokey;").fetchall()]
    c.execute("CREATE TABLE pgbench_history_pk (tid int, bid int, aid int, delta int, mtime timestamp, sk INT8 DEFAULT unique_rowid() PRIMARY KEY);")
    c.execute("INSERT INTO pgbench_history_pk (tid,bid,aid,delta,mtime) VALUES (1,1,1,50,now());")
    kc = c.execute("SELECT count(*) FROM pgbench_history_pk;").fetchone()[0]
res("rowid" in cols and kc == 1, "Keyless Table & Surrogate PK", f"auto_cols={cols} surrogate_pk_rows={kc}")

with cx(h1, p1) as c1, cx(h3, p3) as c3:
    c1.execute("ALTER TABLE crdb_accounts ADD COLUMN tag TEXT DEFAULT 'ok';")
    htag = c3.execute("SELECT count(*) FROM information_schema.columns WHERE table_name='crdb_accounts' AND column_name='tag';").fetchone()[0]
with cx(h1, p1, False) as c:
    try:
        c.execute("CREATE TABLE crdb_tx_ddl (id int PRIMARY KEY); SAVEPOINT sp1; INSERT INTO crdb_tx_ddl VALUES (1); ROLLBACK TO SAVEPOINT sp1; INSERT INTO crdb_tx_ddl VALUES (2);")
        c.commit(); ddl_sp = f"OK:{c.execute('SELECT id FROM crdb_tx_ddl;').fetchall()}"
    except Exception as e: ddl_sp = f"LIMIT:{getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]}"; c.rollback()
res(htag == 1, "DDL Propagation & SAVEPOINT", f"node3_col={htag} tx_ddl_savepoint={ddl_sp}")

with cx(h1, p1) as c:
    pr = []
    for lbl, sql in (
        ("temp_default", "CREATE TEMP TABLE tmp_d (id int);"),
        ("temp_exp_on", "SET experimental_enable_temp_tables='on'; CREATE TEMP TABLE tmp_p (id int);"),
        ("adv_lock", "SELECT pg_try_advisory_lock(42);"),
        ("listen", "LISTEN ch_test;"),
        ("pg_trgm", "CREATE EXTENSION IF NOT EXISTS pg_trgm;"),
        ("uuid_ossp", 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'),
        ("vector_ext", "CREATE EXTENSION IF NOT EXISTS vector;"),
        ("native_vector", "CREATE TABLE vec_probe (id int PRIMARY KEY, v VECTOR(3));"),
    ):
        try: c.execute(sql); pr.append(f"{lbl}=OK")
        except Exception as e: pr.append(f"{lbl}=ERR({getattr(e,'sqlstate','NONE')}:{str(e).splitlines()[0]})")
res("temp_exp_on=OK" in pr, "PG Features & Extensions", " ".join(pr))

with cx(h1, p1) as c:
    for _ in range(30):
        lens = [r[0] for r in c.execute("SELECT array_length(replicas, 1) FROM [SHOW RANGES FROM TABLE crdb_accounts];").fetchall()]
        if lens and min(lens) >= 3: break
        time.sleep(1)
    res(bool(lens) and min(lens) >= 3, "Range Replication RF=3 Settled", f"replica_counts={lens}")
PY
)
while IFS='|' read -r st nm dt; do [ -n "$st" ] && rec "$st" "$nm" "$dt"; done <<< "$PY_OUT"

run_py() { python3 -c "import sys,time,psycopg as pg; d=lambda h,p: f'host={h} port={p} dbname=$DB user=root sslmode=disable'; $1"; }

docker stop crdb_node2 >/dev/null
Q1_OK=$(run_py "
for _ in range(5):
  try:
    with pg.connect(d('$H1',$P1),autocommit=True) as c1: c1.execute(\"INSERT INTO crdb_accounts (id,balance,email) VALUES (101,500,'q1@t.io') ON CONFLICT (id) DO NOTHING;\")
    with pg.connect(d('$H3',$P3),autocommit=True) as c3: print(c3.execute('SELECT balance FROM crdb_accounts WHERE id=101;').fetchone()[0]); sys.exit(0)
  except Exception: time.sleep(2)
print('FAIL')")

docker stop crdb_node3 >/dev/null
Q2_ERR=$(run_py "
try:
  with pg.connect(d('$H1',$P1),connect_timeout=3,autocommit=True) as c1:
    c1.execute(\"SET statement_timeout='4000';\"); c1.execute(\"INSERT INTO crdb_accounts (id,balance,email) VALUES (102,500,'q2@t.io');\"); print('UNEXPECTED_OK')
except Exception as e: print(f\"HALTED({getattr(e,'sqlstate','TIMEOUT')}:{str(e).splitlines()[0]})\")")

docker start crdb_node2 crdb_node3 >/dev/null
for _ in $(seq 1 45); do
    LIVE=$(docker exec crdb_node1 /cockroach/cockroach sql --insecure --host=crdb_node1:26257 \
        -e "SELECT count(*) FROM crdb_internal.gossip_nodes WHERE is_live;" --format=tsv 2>/dev/null | tail -n 1 || echo "0")
    [ "${LIVE:-0}" = "3" ] && break; sleep 2
done
REC_OK=$(run_py "
with pg.connect(d('$H1',$P1),autocommit=True) as c:
  c.execute(\"INSERT INTO crdb_accounts (id,balance,email) VALUES (103,700,'q3@t.io');\"); print(c.execute('SELECT count(*) FROM crdb_accounts WHERE id IN (101,103);').fetchone()[0])")
if [ "$Q1_OK" = "500" ] && echo "$Q2_ERR" | grep -q "HALTED" && [ "$REC_OK" = "2" ]; then
    rec "PASS" "Quorum 1-Down / 2-Down Halt & Recovery" "1_down_RPO0_bal=$Q1_OK 2_down=$Q2_ERR recovered_rows=$REC_OK"
else
    rec "FAIL" "Quorum 1-Down / 2-Down Halt & Recovery" "q1=$Q1_OK q2=$Q2_ERR rec=$REC_OK"
fi

TOT=$((PASS + FAIL))
printf "\n## Summary\n- Passed: %s / %s\n- Failed: %s / %s\n" "$PASS" "$TOT" "$FAIL" "$TOT" >> "$RMD"
printf '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>CockroachDB Report</title></head><body><h1>CockroachDB Cluster Test Report</h1><pre>%s</pre></body></html>\n' "$(cat "$RMD")" > "$RHTML"
echo "=== CockroachDB Summary: Passed=$PASS Failed=$FAIL (Report: $RMD) ==="
[ "$FAIL" -eq 0 ] || exit 1
