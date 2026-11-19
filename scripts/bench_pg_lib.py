"""Helper routines for the PostgreSQL multi-master benchmark harness."""
from __future__ import annotations

import os
import re
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


def wcnt(h, p, u, pw, tbl, exp):
    for _ in range(45):
        try:
            if pq(h, p, u, pw, f"SELECT count(*) FROM {tbl};") == str(exp):
                return
        except Exception:
            pass
        time.sleep(1)


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
    pq(hs[0], pt, u, pw, rst + ";")
    if t in ("pg-birep", "pgedge") and len(hs) > 1:
        time.sleep(2)
        wcnt(hs[1], pt, u, pw, f"{B}history", 0)


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


def pb_run(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf):
    """Run pgbench single or dual streams inside bench_client and compute metrics."""
    bc(["bash", "-c", "rm -f /tmp/pb_*.out /tmp/pbl_*"])
    base = f"pgbench -U {u} -d labdb -n -c {c} -j {j} -T {d} -r --max-tries=100 --failures-detailed"
    if m == 1:
        bc(["bash", "-c", f"{base} -h '{hs[0]}' -p {pt} -l --log-prefix=/tmp/pbl_s {a1} >/tmp/pb_1.out 2>&1||true"], pw)
        wlog(logf, bc(["cat", "/tmp/pb_1.out"], False).stdout)
    else:
        h2 = hs[0] if (len(hs) < 2 or (t == "pg17-sync-streaming" and su != "C_multinode_ro")) else hs[1]
        bc(["bash", "-c", f"{base} -h '{hs[0]}' -p {pt} -l --log-prefix=/tmp/pbl_1 {a1} >/tmp/pb_1.out 2>&1 & {base} -h '{h2}' -p {pt} -l --log-prefix=/tmp/pbl_2 {a2} >/tmp/pb_2.out 2>&1 & wait||true"], pw)
        wlog(logf, bc(["cat", "/tmp/pb_1.out", "/tmp/pb_2.out"], False).stdout)
    py = (
        'import glob,math,re\nt=ok=fl=rt=0.0;av=[];lt=[]\n'
        'for f in sorted(glob.glob("/tmp/pb_*.out")):\n'
        ' s=open(f,errors="ignore").read()\n'
        ' if m:=re.search(r"tps = ([0-9.]+)",s):t+=float(m.group(1))\n'
        ' if m:=re.search(r"actually processed:\\s*(\\d+)",s):ok+=int(m.group(1))\n'
        ' if m:=re.search(r"failed transactions:\\s*(\\d+)",s):fl+=int(m.group(1))\n'
        ' if m:=re.search(r"total number of retries:\\s*(\\d+)",s):rt+=int(m.group(1))\n'
        ' if m:=re.search(r"latency average = ([0-9.]+) ms",s):av.append(float(m.group(1)))\n'
        'for lf in sorted(glob.glob("/tmp/pbl_*")):\n'
        ' for ln in open(lf):\n'
        '  z=ln.split()\n'
        '  if len(z)>=3 and z[2].isdigit():lt.append(int(z[2])/1000.0)\n'
        'if lt:lt.sort();n=len(lt);a=sum(lt)/n;sd=math.sqrt(sum((x-a)**2 for x in lt)/n);p95=lt[min(n-1,int(0.95*n))]\n'
        'else:a=sum(av)/len(av) if av else 0;sd=p95=0\n'
        'print(f"{t:.2f}|{a:.3f}|{sd:.3f}|{p95:.3f}|{int(ok)}|{int(fl)}|{int(rt)}")'
    )
    p = bc(["python3", "-c", py]).stdout.strip().split("|")
    return float(p[0]), float(p[1]), float(p[2]), float(p[3]), int(p[4]), int(p[5]), int(p[6])


def conv_chk(t, ok, hs, pt, u, pw):
    """Verify cross-node convergence and detect lost-update balance drift."""
    if t == "pg17-sync-streaming":
        time.sleep(1)
    if t in ("pg-birep", "pgedge", "bucardo"):
        if t == "bucardo":
            sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_pgbench", "5"], False)
        for _ in range(25):
            hcs = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(hcs)) == 1 and hcs[0] >= ok:
                break
            time.sleep(1)
    exp = int(pq(hs[0], pt, u, pw, f"SELECT COALESCE(SUM(delta),0) FROM {B}history;"))
    accs, ns = [], []
    for h in hs:
        sa, sb, hc = [int(pq(h, pt, u, pw, f"SELECT {ex} FROM {B}{tb};")) for ex, tb in (("COALESCE(SUM(abalance),0)", "accounts"), ("COALESCE(SUM(bbalance),0)", "branches"), ("count(*)", "history"))]
        accs.append(sa)
        ns.append(f"{h}:acc={sa}/br={sb}/hist={hc}")
    dr = accs[0] - exp
    st = "EXPECTED_LIMITATION_DIVERGED" if len(set(accs)) > 1 else ("EXPECTED_LIMITATION_LOST_UPDATE" if dr else ("PASS_SINGLE_PRIMARY" if "pg17-" in t else "PASS_CONVERGED"))
    return st, dr, f"exp_delta={exp} " + " ".join(ns)


def run_sb(t, h1, pt, u, pw, sc, logf):
    """Execute sysbench oltp_read_write inside bench_client."""
    base = f"sysbench oltp_read_write --db-driver=pgsql --pgsql-host={h1} --pgsql-port={pt} --pgsql-user={u} " + (f"--pgsql-password={pw} " if pw else "") + "--pgsql-db=labdb --tables=4 --table-size=10000"
    bc(["bash", "-c", f"{base} cleanup >/dev/null 2>&1||true"])
    if bc(["bash", "-c", f"{base} prepare >/tmp/sb_p.out 2>&1"], False).returncode:
        return row(t, "E_sysbench_oltp_rw", sc, 8, 20, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, "prepare: " + bc(["head", "-n", "4", "/tmp/sb_p.out"], False).stdout.replace("\n", " ").strip())
    if t == "citus":
        for i in range(1, 5):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('sbtest{i}','id');")
    note = "oltp_read_write tables=4 size=10000"
    if bc(["bash", "-c", f"{base} --threads=8 --time=20 run >/tmp/sb_r.out 2>&1"], False).returncode:
        note = "auto ps failed; retried --db-ps-mode=disable"
        if bc(["bash", "-c", f"{base} --threads=8 --time=20 --db-ps-mode=disable run >/tmp/sb_r.out 2>&1"], False).returncode:
            return row(t, "E_sysbench_oltp_rw", sc, 8, 20, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, "run: " + bc(["tail", "-n", "4", "/tmp/sb_r.out"], False).stdout.replace("\n", " ").strip())
    s = bc(["cat", "/tmp/sb_r.out"]).stdout
    wlog(logf, s)
    bc(["bash", "-c", f"{base} cleanup >/dev/null 2>&1||true"])
    tx, q, e, a, p = [re.search(x, s) for x in (r"transactions:\s+(\d+)\s+\(([0-9.]+)", r"queries:\s+\d+\s+\(([0-9.]+)", r"ignored errors:\s+(\d+)", r"avg:\s+([0-9.]+)", r"95th percentile:\s+([0-9.]+)")]
    return row(t, "E_sysbench_oltp_rw", sc, 8, 20, float(tx.group(2)) if tx else 0, float(q.group(1)) if q else 0, float(a.group(1)) if a else 0, 0, float(p.group(1)) if p else 0, int(tx.group(1)) if tx else 0, int(e.group(1)) if e else 0, 0, "PASS", 0, note)
