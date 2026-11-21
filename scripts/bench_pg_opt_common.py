"""Shared constants, runner wrappers, and CSV helpers for optimized PG benchmarks."""
from __future__ import annotations

import csv
import re
import subprocess as sp
import time
from pathlib import Path

from bench_pg_lib import B, COLS, bc, mk_scripts, pq, row, sh, wlog

TOPO_ORDER = [
    "pg17-standalone", "pg17-async-streaming", "pg17-sync-streaming", "pg17-logical",
    "pg-birep", "pg18-standalone", "pg18-async-streaming", "pg18-sync-streaming",
    "pg18-logical", "pg18-birep", "pgedge", "bucardo", "citus", "yugabyte",
    "cockroach", "cockroach-rc", "yt-cluster", "yt-cluster-async",
]
SUITE_ORDER = [
    "A_single_rw", "B1_disjoint_rw", "B2_overlap_rw", "C_multinode_ro", "D_hot_conflict",
    "E_sysbench_oltp_rw", "E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo",
    "E4_sysbench_point_select", "H_append_only_insert",
    "F_wan_netem_10ms", "F_wan_netem_25ms", "F_wan_netem_50ms",
    "G_conc_c1", "G_conc_c4", "G_conc_c8", "G_conc_c16", "G_conc_c32",
]
CONC_LEVELS = [(1, 1), (4, 2), (8, 4), (16, 4), (32, 4)]
STANDALONE_TOPOS = {"pg17-standalone", "pg18-standalone"}
SINGLE_PRIMARY = {
    "pg17-standalone", "pg17-async-streaming", "pg17-sync-streaming", "pg17-logical",
    "pg18-standalone", "pg18-async-streaming", "pg18-sync-streaming", "pg18-logical", "citus",
}
MULTI_WRITER = {
    "pg-birep", "pg18-birep", "pgedge", "bucardo",
    "yugabyte", "cockroach", "cockroach-rc", "yt-cluster", "yt-cluster-async",
}
LOGICAL_SUB = {
    "pg17-logical": "sub_logical",
    "pg18-logical": "sub_pg18_logical",
    "pg-birep": "sub_from_node1",
    "pg18-birep": "sub_from_node1",
}
OPT_PFX = (
    "pg17_", "pg18_", "pg_stream_", "pg_logical_", "pg_birep_", "haproxy_pg",
    "pgedge_", "haproxy_pgedge", "bucardo_", "citus_", "yb_", "crdb_",
    "haproxy_yugabyte", "haproxy_cockroach", "bench_client",
)
SB_RETRY_LUA = (
    'package.path = "/usr/share/sysbench/?.lua;" .. package.path\n'
    'require(os.getenv("SB_LUA"))\n'
    "function sysbench.hooks.sql_error_ignorable(errdesc)\n"
    '  local st = errdesc and errdesc.sql_state or ""\n'
    '  if st == "55409" or st == "40001" or st == "40P01" then\n'
    "    if errdesc.connection then\n"
    '      pcall(function() errdesc.connection:query("ROLLBACK") end)\n'
    "    end\n"
    "    return true\n"
    "  end\n"
    "  return false\n"
    "end\n"
)
YT_RETRY_PY = """import math,random,sys,threading,time,psycopg
md,dur,sc,na,pw,hs=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),sys.argv[5],sys.argv[6].split(",")
te=time.monotonic()+dur;lts=[];ct=[0,0,0,0];lk=threading.Lock()
def w(h):
 c=psycopg.connect(f"host={h} port=5432 dbname=labdb user=postgres password={pw}",autocommit=False);cur=c.cursor();ll=[];lc=[0,0,0,0]
 while time.monotonic()<te:
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
    c.rollback();st=getattr(e,"sqlstate","") or ""
    if st in("40001","40P01"):lc[2]+=1
    elif st=="55409":lc[3]+=1
    else:lc[1]+=1;break
  else:lc[1]+=1
 c.close()
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


def expected_suites(topo: str) -> list[str]:
    """Return expected suite list for a given topology."""
    if topo in STANDALONE_TOPOS:
        return [s for s in SUITE_ORDER if not s.startswith("F_wan_netem_")]
    return list(SUITE_ORDER)


def assert_zero_opt_containers() -> None:
    """Verify no lab or benchmark containers remain."""
    out = sh(["docker", "ps", "-a", "--format", "{{.Names}}"]).stdout
    left = [n.strip() for n in out.splitlines() if n.strip() and (n.strip() in ("yt1", "yt2", "yt3") or n.strip().startswith(OPT_PFX))]
    if left:
        raise RuntimeError(f"Residual lab containers: {left}")


def wcnt_opt(h: str, pt: int, u: str, pw: str, tbl: str, exp: int, to_s: int = 180) -> None:
    """Wait until table count reaches expected value or raise TimeoutError."""
    for _ in range(to_s):
        try:
            if pq(h, pt, u, pw, f"SELECT count(*) FROM {tbl};") == str(exp):
                return
        except Exception:
            pass
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for {tbl} count={exp} on {h}")


def mk_scripts_opt() -> None:
    """Create pgbench, sysbench Lua retry, and YT retry scripts in bench_client."""
    mk_scripts()
    app = "\\set payload random(1,100000)\nINSERT INTO bench_append_events(node_id,payload) VALUES(:nid,:payload);\n"
    for path, content in (("/tmp/s_append.sql", app), ("/tmp/sb_wrap.lua", SB_RETRY_LUA), ("/tmp/yt_retry.py", YT_RETRY_PY)):
        sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", f"cat>{path}"], input=content, text=True, check=True)


def ref_sub(h: str, pt: int, u: str, pw: str, sub: str, cp: str = "false") -> None:
    """Refresh logical replication subscription publication."""
    pq(h, pt, u, pw, f"ALTER SUBSCRIPTION {sub} REFRESH PUBLICATION WITH (copy_data={cp});")


def pb_run_opt(t: str, su: str, m: int, c: int, j: int, d: int, a1: str, a2: str, hs: list[str], pt: int, u: str, pw: str, logf=None):
    """Run pgbench -M prepared with 200 retries and parse throughput and latency."""
    bc(["bash", "-c", "rm -f /tmp/pb_*.out /tmp/pbl_*"])
    base = f"pgbench -U {u} -d labdb -n -M prepared -c {c} -j {j} -T {d} -r --max-tries=200 --failures-detailed"
    if m == 1:
        bc(["bash", "-c", f"{base} -h '{hs[0]}' -p {pt} -l --log-prefix=/tmp/pbl_s {a1} >/tmp/pb_1.out 2>&1||true"], pw)
        if logf is not None:
            wlog(logf, bc(["cat", "/tmp/pb_1.out"], chk=False).stdout)
    else:
        h2 = hs[0] if (len(hs) < 2 or (t in SINGLE_PRIMARY and su != "C_multinode_ro")) else hs[1]
        bc(["bash", "-c", f"{base} -h '{hs[0]}' -p {pt} -l --log-prefix=/tmp/pbl_1 {a1} >/tmp/pb_1.out 2>&1 & {base} -h '{h2}' -p {pt} -l --log-prefix=/tmp/pbl_2 {a2} >/tmp/pb_2.out 2>&1 & wait||true"], pw)
        if logf is not None:
            wlog(logf, bc(["cat", "/tmp/pb_1.out", "/tmp/pb_2.out"], chk=False).stdout)
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
        'if lt:lt.sort();n=len(lts:=lt);a=sum(lts)/n;sd=math.sqrt(sum((x-a)**2 for x in lts)/n);p95=lts[min(n-1,int(0.95*n))]\n'
        'else:a=sum(av)/len(av) if av else 0;sd=p95=0\n'
        'print(f"{t:.2f}|{a:.3f}|{sd:.3f}|{p95:.3f}|{int(ok)}|{int(fl)}|{int(rt)}")'
    )
    p = bc(["python3", "-c", py]).stdout.strip().split("|")
    bc(["bash", "-c", "rm -f /tmp/pb_*.out /tmp/pbl_*"], chk=False)
    return float(p[0]), float(p[1]), float(p[2]), float(p[3]), int(p[4]), int(p[5]), int(p[6])


def conv_chk_opt(t: str, ok: int, hs: list[str], pt: int, u: str, pw: str) -> tuple[str, int, str]:
    """Wait for cross-node catch-up and compute balance drift status."""
    if t == "bucardo":
        sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_pgbench", "5"], False)
    if len(hs) > 1:
        for _ in range(45):
            hcs = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(hcs)) == 1 and hcs[0] >= ok:
                break
            time.sleep(1)
    exp = int(pq(hs[0], pt, u, pw, f"SELECT COALESCE(SUM(delta),0) FROM {B}history;"))
    accs = [int(pq(h, pt, u, pw, f"SELECT COALESCE(SUM(abalance),0) FROM {B}accounts;")) for h in hs]
    hcs = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;")) for h in hs]
    dr = accs[0] - exp
    if len(set(accs)) > 1:
        st = "EXPECTED_LIMITATION_DIVERGED"
    elif dr:
        st = "EXPECTED_LIMITATION_LOST_UPDATE"
    elif t in SINGLE_PRIMARY:
        st = "PASS_SINGLE_PRIMARY"
    else:
        st = "PASS_CONVERGED"
    return st, dr, f"d={exp} acc={'/'.join(map(str, accs))} h={'/'.join(map(str, hcs))}"


def completed_topologies(path: Path) -> set[str]:
    """Return topologies that already have all expected suites recorded in CSV."""
    if not path.is_file():
        return set()
    seen: dict[str, set[str]] = {}
    with path.open(encoding="utf-8", newline="") as fh:
        for r in csv.DictReader(fh):
            seen.setdefault(r["topology"], set()).add(r["suite"])
    return {t for t in TOPO_ORDER if set(expected_suites(t)).issubset(seen.get(t, set()))}


def upsert_opt_csv(path: Path, topo: str, new_rows: list[dict]) -> None:
    """Atomically upsert one topology's benchmark rows in canonical CSV order."""
    cur: list[dict] = []
    if path.is_file():
        with path.open(encoding="utf-8", newline="") as fh:
            cur = list(csv.DictReader(fh))
    merged = [r for r in cur if r["topology"] != topo] + new_rows
    ti, si = {k: i for i, k in enumerate(TOPO_ORDER)}, {k: i for i, k in enumerate(SUITE_ORDER)}
    merged.sort(key=lambda r: (ti.get(r["topology"], 999), si.get(r["suite"], 999)))
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".csv.tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(merged)
    tmp.replace(path)
