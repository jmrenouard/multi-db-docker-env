"""Helper routines for the PostgreSQL multi-master benchmark harness."""
from __future__ import annotations

import csv
import os
import re
import shlex
import subprocess as sp
import time
from pathlib import Path

B = "pgbench_"
COLS = (
    "topology,suite,pg_scale,clients,duration_s,tps,qps,lat_avg_ms,"
    "lat_stddev_ms,lat_p95_ms,tx_committed,tx_failed,retries_40001,"
    "convergence_status,balance_drift,notes"
).split(",")


def row(*v): return dict(zip(COLS, v))


def sh(c, chk=True):
    p = sp.run(c, text=True, capture_output=True, check=False)
    if chk and p.returncode != 0:
        raise RuntimeError(f"rc={p.returncode} cmd={c} err={p.stderr}")
    return p


def de(ct, a, pw="", chk=True): return sh(["docker", "exec", "-e", f"PGPASSWORD={pw}", ct, *a], chk)
def bc(a, pw="", chk=True): return de("bench_client", a, pw, chk)
def pq(h, p, u, pw, q): return bc(["psql", "-h", h, "-p", str(p), "-U", u, "-d", "labdb", "-v", "ON_ERROR_STOP=1", "-tAc", q], pw).stdout.strip()


def wcnt(h, p, u, pw, tbl, exp, to_s=45):
    for _ in range(to_s):
        try:
            if pq(h, p, u, pw, f"SELECT count(*) FROM {tbl};") == str(exp):
                return
        except Exception:
            pass
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for {tbl} count={exp} on {h}")


def bctl(act):
    sh(["docker", "exec", "bucardo_daemon", "bucardo", act], act == "start")
    want = 1 if act == "stop" else 0
    for _ in range(15):
        rc = sh(["docker", "exec", "bucardo_daemon", "test", "-f", "/var/run/bucardo/bucardo.mcp.pid"], False).returncode
        if (rc != 0) == bool(want):
            break
        time.sleep(1)
    time.sleep(1 if want else 2)


def mk_scripts():
    q = (
        f"BEGIN;UPDATE {B}accounts SET abalance=abalance+:delta WHERE aid=:aid;"
        f"SELECT abalance FROM {B}accounts WHERE aid=:aid;"
        f"UPDATE {B}tellers SET tbalance=tbalance+:delta WHERE tid=:tid;"
        f"UPDATE {B}branches SET bbalance=bbalance+:delta WHERE bid=:bid;"
        f"INSERT INTO {B}history(tid,bid,aid,delta,mtime)VALUES(:tid,:bid,:aid,:delta,CURRENT_TIMESTAMP);END;"
    )
    specs = (
        ("d1", "aid random(1,:half)\n\\set tid random(1,10)\n\\set bid 1\n\\set delta random(-5000,5000)"),
        ("d2", "aid random(:half1,:nacc)\n\\set tid random(11,20)\n\\set bid 2\n\\set delta random(-5000,5000)"),
        ("ov", "aid random(1,:nacc)\n\\set bid random(1,:scale)\n\\set tid random(1,10*:scale)\n\\set delta random(-5000,5000)"),
    )
    for f, hdr in specs:
        sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", f"cat>/tmp/s_{f}.sql"], input=f"\\set {hdr}\n{q}\n", text=True, check=True)
    hot = (
        f"\\set aid random(1,50)\n\\set delta random(1,100)\nBEGIN;\n"
        f"UPDATE {B}accounts SET abalance=abalance+:delta WHERE aid=:aid;\n"
        f"INSERT INTO {B}history(tid,bid,aid,delta,mtime)VALUES(1,1,:aid,:delta,CURRENT_TIMESTAMP);\nEND;\n"
    )
    sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", "cat>/tmp/s_hot.sql"], input=hot, text=True, check=True)


def init_ds(t, hs, pt, u, pw, sc, na):
    h1 = hs[0]
    pbi = ["pgbench", "-U", u, "-d", "labdb", "-i", "-s", str(sc), "-I", "g", "-n", "-q"]
    ddl = (
        f"DROP TABLE IF EXISTS {B}history,{B}accounts,{B}tellers,{B}branches CASCADE;"
        f"CREATE TABLE {B}branches(bid INT PRIMARY KEY,bbalance INT,filler CHAR(88));"
        f"CREATE TABLE {B}tellers(tid INT PRIMARY KEY,bid INT,tbalance INT,filler CHAR(84));"
        f"CREATE TABLE {B}accounts(aid INT PRIMARY KEY,bid INT,abalance INT,filler CHAR(84));"
    )
    hc = "tid INT,bid INT,aid INT,delta INT,mtime TIMESTAMP,filler CHAR(22)"
    if t in ("pg-birep", "bucardo"):
        if t == "bucardo":
            bctl("stop")
        for i, h in enumerate(hs, 1):
            pq(h, pt, u, pw, f"{ddl}DROP SEQUENCE IF EXISTS {B}history_hid_seq CASCADE;CREATE SEQUENCE {B}history_hid_seq INCREMENT BY 2 START WITH {i};CREATE TABLE {B}history(hid BIGINT PRIMARY KEY DEFAULT nextval('{B}history_hid_seq'),{hc});")
            if t == "bucardo":
                bc([*pbi, "-h", h, "-p", str(pt)], pw)
        if t == "pg-birep":
            for n, s in ((hs[0], "2"), (hs[1], "1")):
                pq(n, pt, u, pw, f"ALTER SUBSCRIPTION sub_from_node{s} REFRESH PUBLICATION WITH (copy_data=false);")
            time.sleep(2)
            bc([*pbi, "-h", h1, "-p", str(pt)], pw)
            wcnt(hs[1], pt, u, pw, f"{B}accounts", na)
        else:
            cmd = f"bucardo list sync|grep -q sync_pgbench||bucardo add sync sync_pgbench dbs=grp_mm tables=public.{B}branches,public.{B}tellers,public.{B}accounts,public.{B}history conflict_strategy=bucardo_latest"
            sh(["docker", "exec", "bucardo_daemon", "bash", "-lc", cmd])
            bctl("start")
        return
    hdef = {
        "pgedge": f"hid BIGINT PRIMARY KEY DEFAULT snowflake.nextval('snowflake.id_seq'),{hc}",
        "citus": f"hid BIGSERIAL,{hc},PRIMARY KEY(aid,hid)",
        "cockroach": f"hid INT8 DEFAULT unique_rowid() PRIMARY KEY,{hc}",
    }.get(t, f"hid BIGSERIAL PRIMARY KEY,{hc}")
    pq(h1, pt, u, pw, f"{ddl}CREATE TABLE {B}history({hdef});")
    if t == "pgedge":
        for n in hs[1:]:
            wcnt(n, pt, u, pw, f"information_schema.tables WHERE table_name='{B}history'", 1)
    elif t == "citus":
        for tbl, col in (("branches", "bid"), ("tellers", "tid"), ("accounts", "aid"), ("history", "aid")):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('{B}{tbl}','{col}');")
    bc([*pbi, "-h", h1, "-p", str(pt)], pw)
    if t == "pgedge":
        for n in hs[1:]:
            wcnt(n, pt, u, pw, f"{B}accounts", na)


def assert_zero_containers(prefixes, exact=(), label="Residual PoC containers", sh_fn=None):
    """Verify no lab or benchmark containers matching prefixes or names remain."""
    out = (sh_fn or sh)(["docker", "ps", "-a", "--format", "{{.Names}}"]).stdout
    left = [n.strip() for n in out.splitlines() if n.strip() and (n.strip() in exact or n.strip().startswith(prefixes))]
    if left:
        raise RuntimeError(f"{label}: {left}")


def tc_netem(pc, img, args, chk=True, sh_fn=None):
    """Run tc qdisc inside a container network namespace."""
    (sh_fn or sh)(["docker", "run", "--rm", "--network", f"container:{pc}", "--cap-add", "NET_ADMIN", img, "tc", "qdisc", *args], chk)


def ref_sub(h, pt, u, pw, sub, cp="false", pq_fn=None):
    """Refresh logical replication subscription publication."""
    (pq_fn or pq)(h, pt, u, pw, f"ALTER SUBSCRIPTION {sub} REFRESH PUBLICATION WITH (copy_data={cp});")


def wait_wal_replay(h, pt, u, pw, to_s=30, pq_fn=None):
    """Poll pg_stat_replication until replay_lsn reaches primary current WAL LSN."""
    run_pq = pq_fn or pq
    lsn = run_pq(h, pt, u, pw, "SELECT pg_current_wal_lsn();").strip()
    q = f"SELECT count(*) FROM pg_stat_replication WHERE replay_lsn IS NULL OR replay_lsn < pg_lsn('{lsn}');"
    for _ in range(to_s):
        if run_pq(h, pt, u, pw, q) == "0":
            return
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for WAL replay >= {lsn} on {h}")


def wait_sub_ready(h, pt, u, pw, sub, n_tables=4, to_s=30, pq_fn=None):
    """Wait until all matching sysbench tables in a subscription reach srsubstate='r'."""
    run_pq = pq_fn or pq
    q = (
        "SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid "
        f"JOIN pg_class c ON c.oid=r.srrelid WHERE s.subname='{sub}' AND c.relname LIKE 'sbtest%' AND r.srsubstate='r';"
    )
    for _ in range(to_s):
        if run_pq(h, pt, u, pw, q) == str(n_tables):
            return
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for subscription {sub} ready on {h}")


def drop_sb_sub(hs, pt, u, pw, sub, birep=False, pq_fn=None):
    """Drop sysbench tables on peer and refresh logical/bi-dir subscriptions."""
    run_pq = pq_fn or pq
    run_pq(hs[1], pt, u, pw, "DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
    ref_sub(hs[1], pt, u, pw, sub, pq_fn=run_pq)
    if birep:
        ref_sub(hs[0], pt, u, pw, "sub_from_node2", pq_fn=run_pq)


def run_wan_netem(t, delay_ms, dur, hs, pt, u, pw, sc, netem, img, pb_fn, reset_fn, logf=None, warm_s=0, chk_hs=None, note=None, tc_fn=None):
    """Inject tc netem delay on peers, optionally warm up, run pgbench RW, and clean qdisc."""
    vhs = chk_hs or hs
    tc_op = tc_fn or tc_netem
    suite = f"F_wan_netem_{delay_ms}ms"
    reset_fn(t, vhs, pt, u, pw)
    for pc in netem:
        tc_op(pc, img, ["replace", "dev", "eth0", "root", "netem", "delay", f"{delay_ms}ms"])
    time.sleep(1)
    try:
        if warm_s > 0:
            pb_fn(t, suite, 1, 8, 4, warm_s, f"-D scale={sc}", "", hs, pt, u, pw, None)
            reset_fn(t, vhs, pt, u, pw)
        tps, avg, sdv, p95, ok, fl, rt = pb_fn(t, suite, 1, 8, 4, dur, f"-D scale={sc}", "", hs, pt, u, pw, logf)
    finally:
        for pc in netem:
            tc_op(pc, img, ["del", "dev", "eth0", "root"], False)
        time.sleep(1)
    return row(t, suite, sc, 8, dur, tps, "N/A", avg, sdv, p95, ok, fl, rt, f"PASS_NETEM_{delay_ms}MS", 0, note or f"tc netem {delay_ms}ms ({','.join(netem)})")


def reset_ds(t, hs, pt, u, pw):
    """Reset pgbench balances and history between suites."""
    rst = f"UPDATE {B}accounts SET abalance=0 WHERE abalance<>0;UPDATE {B}branches SET bbalance=0;UPDATE {B}tellers SET tbalance=0;TRUNCATE {B}history"
    if t == "bucardo":
        bctl("stop")
        sql = f"{rst};DO $$ DECLARE r RECORD; BEGIN FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='bucardo' AND tablename LIKE 'delta_public_{B}%' LOOP EXECUTE 'TRUNCATE bucardo.'||quote_ident(r.tablename); END LOOP; END $$;"
        for h in hs:
            pq(h, pt, u, pw, sql)
        bctl("start")
        return
    if t in ("pg-birep", "pg18-birep", "pgedge") and len(hs) > 1:
        for _ in range(30):
            cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(cnts)) == 1:
                break
            time.sleep(1)
    pq(hs[0], pt, u, pw, rst + ";")
    if t in ("pg-birep", "pg18-birep", "pgedge") and len(hs) > 1:
        time.sleep(2)
        wcnt(hs[1], pt, u, pw, f"{B}history", 0)
        if t in ("pg-birep", "pg18-birep"):
            bal_rst = f"UPDATE {B}accounts SET abalance=0 WHERE abalance<>0;UPDATE {B}branches SET bbalance=0;UPDATE {B}tellers SET tbalance=0;"
            for n in hs[1:]:
                pq(n, pt, u, pw, bal_rst)
            time.sleep(1)


def wlog(logf, txt):
    """Write sanitized summary log deduplicating repetitive NOTICE/statement lines."""
    nc = 0
    for ln in txt.splitlines():
        if "NOTICE:  No license is installed" in ln:
            nc += 1
            if nc <= 2:
                logf.write(ln + "\n")
            elif nc == 3:
                logf.write("[... repeated NOTICE lines omitted ...]\n")
        elif not re.match(r"^\s+[0-9.]+\s+\d+\s+\d+\s+", ln) and not ln.startswith("statement latencies"):
            logf.write(ln + "\n")


def pb_run(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf=None, prepared=False, max_tries=100, single_primary=None, sample_rate=None, bc_fn=None):
    """Run pgbench single or dual streams inside bench_client and verify exit status."""
    run_bc = bc_fn or bc
    run_bc(["bash", "-c", "rm -f /tmp/pb_*.out /tmp/pbl_*"])
    pm = "-M prepared " if prepared else ""
    sr = 0.05 if (sample_rate is None and su == "C_multinode_ro") else sample_rate
    sf = f" --sampling-rate={sr}" if sr else ""
    base = f"pgbench -U {shlex.quote(str(u))} -d labdb -n {pm}-c {c} -j {j} -T {d} -r --max-tries={max_tries} --failures-detailed"
    try:
        if m == 1:
            res = run_bc(["bash", "-c", f"{base} -h {shlex.quote(hs[0])} -p {pt} -l --log-prefix=/tmp/pbl_s{sf} {a1} >/tmp/pb_1.out 2>&1"], pw, False)
            out_txt = run_bc(["cat", "/tmp/pb_1.out"], chk=False).stdout
        else:
            sp_set = single_primary if single_primary is not None else {"pg17-sync-streaming"}
            h2 = hs[0] if (len(hs) < 2 or (t in sp_set and su != "C_multinode_ro")) else hs[1]
            cmd = (
                f"{base} -h {shlex.quote(hs[0])} -p {pt} -l --log-prefix=/tmp/pbl_1{sf} {a1} >/tmp/pb_1.out 2>&1 & p1=$!; "
                f"{base} -h {shlex.quote(h2)} -p {pt} -l --log-prefix=/tmp/pbl_2{sf} {a2} >/tmp/pb_2.out 2>&1 & p2=$!; "
                'r1=0; wait "$p1" || r1=$?; r2=0; wait "$p2" || r2=$?; exit $((r1 != 0 ? r1 : r2))'
            )
            res = run_bc(["bash", "-c", cmd], pw, False)
            out_txt = run_bc(["cat", "/tmp/pb_1.out", "/tmp/pb_2.out"], chk=False).stdout
        if logf is not None:
            wlog(logf, out_txt)
        if res.returncode != 0 or "Run was aborted" in out_txt:
            raise RuntimeError(f"pgbench failed for {t}/{su} (rc={res.returncode}): {out_txt.strip()[:240]}")
        py = (
            'import glob,math,re\nt=ok=fl=rt=0.0;av=[];lt=[]\n'
            'for f in sorted(glob.glob("/tmp/pb_*.out")):\n'
            ' with open(f,errors="ignore") as fh: s=fh.read()\n'
            ' if m:=re.search(r"tps = ([0-9.]+)",s):t+=float(m.group(1))\n'
            ' if m:=re.search(r"actually processed:\\s*(\\d+)",s):ok+=int(m.group(1))\n'
            ' if m:=re.search(r"failed transactions:\\s*(\\d+)",s):fl+=int(m.group(1))\n'
            ' if m:=re.search(r"total number of retries:\\s*(\\d+)",s):rt+=int(m.group(1))\n'
            ' if m:=re.search(r"latency average = ([0-9.]+) ms",s):av.append(float(m.group(1)))\n'
            'for lf in sorted(glob.glob("/tmp/pbl_*")):\n'
            ' with open(lf) as fh:\n'
            '  for ln in fh:\n'
            '   z=ln.split()\n'
            '   if len(z)>=3 and z[2].isdigit():lt.append(int(z[2])/1000.0)\n'
            'if lt:lt.sort();n=len(lt);a=sum(lt)/n;sd=math.sqrt(sum((x-a)**2 for x in lt)/n);p95=lt[min(n-1,int(0.95*n))]\n'
            'else:a=sum(av)/len(av) if av else 0;sd=p95=0\n'
            'print(f"{t:.2f}|{a:.3f}|{sd:.3f}|{p95:.3f}|{int(ok)}|{int(fl)}|{int(rt)}")'
        )
        p = run_bc(["python3", "-c", py]).stdout.strip().split("|")
        tps, avg, sdv, p95, ok, fl, rt = float(p[0]), float(p[1]), float(p[2]), float(p[3]), int(p[4]), int(p[5]), int(p[6])
        if tps == 0 and ok == 0:
            raise RuntimeError(f"pgbench produced zero transactions for {t}/{su}: {out_txt.strip()[:240]}")
        return tps, avg, sdv, p95, ok, fl, rt
    finally:
        run_bc(["bash", "-c", "rm -f /tmp/pb_*.out /tmp/pbl_*"], chk=False)


def conv_chk(t, ok, hs, pt, u, pw, single_primary=None, wait_s=25, short_notes=False, pq_fn=None, sh_fn=None):
    """Verify cross-node convergence and detect lost-update balance drift."""
    run_pq = pq_fn or pq
    run_sh = sh_fn or sh
    if t == "pg17-sync-streaming" and not short_notes:
        time.sleep(1)
    if t == "bucardo":
        run_sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_pgbench", "5"], False)
    if (short_notes and len(hs) > 1) or t in ("pg-birep", "pgedge", "bucardo"):
        for _ in range(wait_s):
            hcs = [int(run_pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(hcs)) == 1 and hcs[0] >= ok:
                break
            time.sleep(1)
    exp = int(run_pq(hs[0], pt, u, pw, f"SELECT COALESCE(SUM(delta),0) FROM {B}history;"))
    accs, ns, hcs = [], [], []
    for h in hs:
        if short_notes:
            sa = int(run_pq(h, pt, u, pw, f"SELECT COALESCE(SUM(abalance),0) FROM {B}accounts;"))
            hc = int(run_pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;"))
            accs.append(sa)
            hcs.append(hc)
        else:
            sa, sb, hc = [int(run_pq(h, pt, u, pw, f"SELECT {ex} FROM {B}{tb};")) for ex, tb in (("COALESCE(SUM(abalance),0)", "accounts"), ("COALESCE(SUM(bbalance),0)", "branches"), ("count(*)", "history"))]
            accs.append(sa)
            ns.append(f"{h}:acc={sa}/br={sb}/hist={hc}")
    dr = accs[0] - exp
    is_sp = (t in single_primary) if single_primary is not None else ("pg17-" in t)
    st = "EXPECTED_LIMITATION_DIVERGED" if len(set(accs)) > 1 else ("EXPECTED_LIMITATION_LOST_UPDATE" if dr else ("PASS_SINGLE_PRIMARY" if is_sp else "PASS_CONVERGED"))
    note = f"d={exp} acc={'/'.join(map(str, accs))} h={'/'.join(map(str, hcs))}" if short_notes else (f"exp_delta={exp} " + " ".join(ns))
    return st, dr, note


def run_sb(t, h1, pt, u, pw, sc, logf):
    """Execute sysbench oltp_read_write inside bench_client."""
    pwa = '--pgsql-password="$PGPASSWORD" ' if pw else ""
    base = f"sysbench oltp_read_write --db-driver=pgsql --pgsql-host={shlex.quote(str(h1))} --pgsql-port={pt} --pgsql-user={shlex.quote(str(u))} {pwa}--pgsql-db=labdb --tables=4 --table-size=10000"
    bc(["bash", "-c", f"{base} cleanup >/dev/null 2>&1||true"], pw)
    if bc(["bash", "-c", f"{base} prepare >/tmp/sb_p.out 2>&1"], pw, chk=False).returncode:
        return row(t, "E_sysbench_oltp_rw", sc, 8, 20, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, "prepare: " + bc(["head", "-n", "4", "/tmp/sb_p.out"], chk=False).stdout.replace("\n", " ").strip())
    if t == "citus":
        for i in range(1, 5):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('sbtest{i}','id');")
    note = "oltp_read_write tables=4 size=10000"
    if bc(["bash", "-c", f"{base} --threads=8 --time=20 run >/tmp/sb_r.out 2>&1"], pw, chk=False).returncode:
        note = "auto ps failed; retried --db-ps-mode=disable"
        if bc(["bash", "-c", f"{base} --threads=8 --time=20 --db-ps-mode=disable run >/tmp/sb_r.out 2>&1"], pw, chk=False).returncode:
            return row(t, "E_sysbench_oltp_rw", sc, 8, 20, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, "run: " + bc(["tail", "-n", "4", "/tmp/sb_r.out"], chk=False).stdout.replace("\n", " ").strip())
    s = bc(["cat", "/tmp/sb_r.out"]).stdout
    wlog(logf, s)
    bc(["bash", "-c", f"{base} cleanup >/dev/null 2>&1||true"], pw)
    tx, q, e, a, p = [re.search(x, s) for x in (r"transactions:\s+(\d+)\s+\(([0-9.]+)", r"queries:\s+\d+\s+\(([0-9.]+)", r"ignored errors:\s+(\d+)", r"avg:\s+([0-9.]+)", r"95th percentile:\s+([0-9.]+)")]
    return row(t, "E_sysbench_oltp_rw", sc, 8, 20, float(tx.group(2)) if tx else 0, float(q.group(1)) if q else 0, float(a.group(1)) if a else 0, 0, float(p.group(1)) if p else 0, int(tx.group(1)) if tx else 0, int(e.group(1)) if e else 0, 0, "PASS", 0, note)


YT_RETRY_PY = """import math,random,sys,threading,time,psycopg
md,dur,sc,na,pw,hs=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),sys.argv[5],sys.argv[6].split(",")
te=time.monotonic()+dur;lts=[];ct=[0,0,0,0];lk=threading.Lock()
def op(h):
 c=psycopg.connect(host=h,port=5432,dbname="labdb",user="postgres",password=pw,autocommit=False);return c,c.cursor()
def w(h):
 ll=[];lc=[0,0,0,0];c=cur=None
 try:
  c,cur=op(h)
 except psycopg.Error:
  lc[1]+=1;c=None
 while c is not None and time.monotonic()<te:
  t0=time.monotonic();aid=random.randint(1,50 if md=="hot" else na);dl=random.randint(1,100) if md=="hot" else random.randint(-5000,5000)
  bid=1 if md=="hot" else random.randint(1,sc);tid=1 if md=="hot" else random.randint(1,10*sc)
  for _ in range(100):
   if time.monotonic()>=te:break
   try:
    cur.execute("UPDATE pgbench_accounts SET abalance=abalance+%s WHERE aid=%s",(dl,aid))
    if md!="hot":
     cur.execute("SELECT abalance FROM pgbench_accounts WHERE aid=%s",(aid,))
     cur.execute("UPDATE pgbench_tellers SET tbalance=tbalance+%s WHERE tid=%s",(dl,tid))
     cur.execute("UPDATE pgbench_branches SET bbalance=bbalance+%s WHERE bid=%s",(dl,bid))
    cur.execute("INSERT INTO pgbench_history(tid,bid,aid,delta,mtime) VALUES(%s,%s,%s,%s,CURRENT_TIMESTAMP)",(tid,bid,aid,dl))
    c.commit();lc[0]+=1;ll.append((time.monotonic()-t0)*1000);break
   except psycopg.Error as e:
    st=getattr(e,"sqlstate","") or "";rb_err=False
    try:
     if not getattr(c,"closed",False):c.rollback()
    except psycopg.Error:
     rb_err=True
    if rb_err or getattr(c,"closed",False) or getattr(c,"broken",False):
     try:c.close()
     except psycopg.Error:pass
     try:c,cur=op(h)
     except psycopg.Error:lc[1]+=1;c=None;break
     lc[1]+=1;break
    if st in("40001","40P01"):lc[2]+=1
    elif st=="55409":lc[3]+=1
    else:lc[1]+=1;break
  else:lc[1]+=1
 if c is not None:
  try:c.close()
  except psycopg.Error:pass
 with lk:
  lts.extend(ll)
  for i in range(4):ct[i]+=lc[i]
ts=[threading.Thread(target=w,args=(h,)) for h in hs for _ in range(4)];t0=time.monotonic()
for t in ts:t.start()
for t in ts:t.join()
el=max(time.monotonic()-t0,1e-4)
if lts:lts.sort();n=len(lts);a=sum(lts)/n;sd=math.sqrt(sum((x-a)**2 for x in lts)/n);p95=lts[min(n-1,int(0.95*n))]
else:a=sd=p95=0.0
print(f"{ct[0]/el:.2f}|{a:.3f}|{sd:.3f}|{p95:.3f}|{ct[0]}|{ct[1]}|{ct[2]+ct[3]}|{ct[2]}|{ct[3]}")
"""


def write_csv_atomic(path: Path, rows: list[dict]) -> None:
    """Atomically write benchmark rows with the standard COLS header."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".csv.tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    tmp.replace(path)


def upsert_csv(path: Path, topo: str, new_rows: list[dict], topo_order: list[str], suite_order: list[str]) -> None:
    """Atomically upsert one topology's benchmark rows in canonical CSV order."""
    cur: list[dict] = []
    if path.is_file():
        with path.open(encoding="utf-8", newline="") as fh:
            cur = list(csv.DictReader(fh))
    merged = [r for r in cur if r["topology"] != topo] + new_rows
    ti, si = {k: i for i, k in enumerate(topo_order)}, {k: i for i, k in enumerate(suite_order)}
    merged.sort(key=lambda r: (ti.get(r["topology"], 999), si.get(r["suite"], 999)))
    write_csv_atomic(path, merged)
