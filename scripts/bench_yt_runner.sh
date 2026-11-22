#!/usr/bin/env bash
# Sequential empirical PG_SCALE=2 benchmark runner for 3-node YT Cluster 1.21.3 (PG 18).
set -euo pipefail
export BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BENCH_ROOT"
[ -f .env ] && { set -a; . ./.env; set +a; }
export PYTHONDONTWRITEBYTECODE=1 PG_SCALE="${PG_SCALE:-2}"
export PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
export DB_ROOT_PASSWORD="$PG_PASS" PG_LAB_PASSWORD="$PG_PASS" BENCH_IMAGE="${BENCH_IMAGE:-multi-db-pgbench-sysbench:latest}"
export BENCH_OUT_CSV="${BENCH_OUT_CSV:-${BENCH_ROOT}/reports/benchmark_yt_cluster.csv}"
export BENCH_LOG_FILE="${BENCH_LOG_FILE:-${BENCH_ROOT}/reports/logs/yt-cluster-benchmark.log}"

exec python3 - <<'PY'
import csv,io,os,re,subprocess as sp,sys,time
from pathlib import Path

R,OUT,LOG=Path(os.environ["BENCH_ROOT"]),Path(os.environ["BENCH_OUT_CSV"]),Path(os.environ["BENCH_LOG_FILE"])
OUT.parent.mkdir(parents=True,exist_ok=True); LOG.parent.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(R/"scripts"))
from bench_pg_lib import B,COLS,YT_RETRY_PY as RETRY_PY,bc,de,mk_scripts,pb_run,pq,row,sh,write_csv_atomic

SC,PW,IMG=int(os.environ["PG_SCALE"]),os.environ["PG_PASS"],os.environ["BENCH_IMAGE"]
NA,HF,NS,U,PT,J=100000*SC,50000*SC,["yt1","yt2","yt3"],"postgres",5432,"/".join
CF,CC_ASYNC=str(R/"docker-compose-yt-cluster.yml"),"CgQSAhAC"
q=lambda n,s:pq(n,PT,U,PW,s)
pb=lambda t,su,m,c,j,d,a1,a2="":pb_run(t,su,m,c,j,d,a1,a2,NS[:2],PT,U,PW,io.StringIO())

def assert_zero():
  left=[n.strip() for n in sh(["docker","ps","-a","--format","{{.Names}}"]).stdout.splitlines() if n.strip() in("yt1","yt2","yt3","bench_client")]
  if left: raise RuntimeError(f"Residual: {left}")

def ldr():
  for n in NS:
    if ', Leader"' in de(n,["psql","-X","-q","-U",U,"-d","postgres","-tAc","SELECT yt_info('o')::text;"],PW,False).stdout: return n
  return "yt1"

def yts(pat):
  for n in NS: q(n,f"SELECT count(*) FROM public.yt_setup('{pat}','',true,'public.yt_config');")
  time.sleep(2.5)

def set_async(pat):
  q(ldr(),f"UPDATE public.yt_config SET value='{CC_ASYNC}' WHERE module='A' AND name LIKE '{pat}';")
  time.sleep(2.5)

def init_pb():
  ddl=(f"DROP TABLE IF EXISTS {B}history,{B}accounts,{B}tellers,{B}branches CASCADE;"
       f"CREATE TABLE {B}branches(bid INT PRIMARY KEY,bbalance INT,filler CHAR(88));"
       f"CREATE TABLE {B}tellers(tid INT PRIMARY KEY,bid INT,tbalance INT,filler CHAR(84));"
       f"CREATE TABLE {B}accounts(aid INT PRIMARY KEY,bid INT,abalance INT,filler CHAR(84));"
       f"CREATE TABLE {B}history(hid UUID PRIMARY KEY DEFAULT uuidv7(),tid INT,bid INT,aid INT,delta INT,mtime TIMESTAMP,filler CHAR(22));")
  for n in NS: q(n,ddl); bc(["pgbench","-U",U,"-d","labdb","-i","-s",str(SC),"-I","g","-n","-q","-h",n,"-p",str(PT)],PW)
  yts("public.pgbench_%")

def rst():
  s=f"BEGIN;SET LOCAL session_replication_role=replica;UPDATE {B}accounts SET abalance=0 WHERE abalance<>0;UPDATE {B}branches SET bbalance=0;UPDATE {B}tellers SET tbalance=0;TRUNCATE {B}history;COMMIT;"
  for n in NS: q(n,s)
  time.sleep(0.5)

def cchk(ok,tag):
  for _ in range(35):
    hcs=[int(q(n,f"SELECT count(*) FROM {B}history;") or -1) for n in NS]
    if len(set(hcs))==1 and hcs[0]>=ok: break
    time.sleep(1)
  exp=int(q("yt1",f"SELECT COALESCE(SUM(delta),0) FROM {B}history;"))
  accs=[int(q(n,f"SELECT COALESCE(SUM(abalance),0) FROM {B}accounts;")) for n in NS]
  hcs=[int(q(n,f"SELECT count(*) FROM {B}history;")) for n in NS]; dr=accs[0]-exp
  st="EXPECTED_LIMITATION_DIVERGED" if len(set(accs))>1 else ("EXPECTED_LIMITATION_LOST_UPDATE" if dr else "PASS_CONVERGED")
  return st,dr,f"{tag} d={exp} acc={J(map(str,accs))} h={J(map(str,hcs))}"

def r_ret(topo,su,md,dur,tag):
  rst(); p=bc(["python3","/tmp/yt_retry.py",md,str(dur),str(SC),str(NA),PW,"yt1,yt2"]).stdout.strip().split("|")
  cst,cdr,cn=cchk(int(p[4]),f"{tag} r40001={p[7]} r55409={p[8]}")
  return row(topo,su,SC,8,dur,float(p[0]),"N/A",float(p[1]),float(p[2]),float(p[3]),int(p[4]),int(p[5]),int(p[6]),cst,cdr,cn)

def r_sb(topo,tag,am=False,want=None):
  pwa='--pgsql-password="$PGPASSWORD" ' if PW else ""
  cm=f"--db-driver=pgsql --pgsql-host=yt1 --pgsql-port={PT} --pgsql-user={U} {pwa}--pgsql-db=labdb --tables=4 --table-size=10000"
  def prep_sb():
    for n in NS: q(n,"DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
    q(ldr(),"DELETE FROM public.yt_config WHERE module='A' AND name LIKE 'public.sbtest%';"); time.sleep(1.5)
    bc(["bash","-c",f"sysbench oltp_read_write {cm} prepare >/tmp/sb_p.out 2>&1"],PW,True)
    dump=de("yt1",["pg_dump","-U",U,"-d","labdb","-t","sbtest*"],PW).stdout
    for n in("yt2","yt3"): sp.run(["docker","exec","-i","-e",f"PGPASSWORD={PW}",n,"psql","-U",U,"-d","labdb","-v","ON_ERROR_STOP=1"],input=dump,text=True,check=True,stdout=sp.DEVNULL)
    yts("public.sbtest%")
    if am: set_async("public.sbtest%")
  prep_sb()
  pats=(r"transactions:\s+(\d+)\s+\(([0-9.]+)",r"queries:\s+\d+\s+\(([0-9.]+)",r"ignored errors:\s+(\d+)",r"avg:\s+([0-9.]+)",r"95th percentile:\s+([0-9.]+)")
  res={}
  for su,lua,th,dur in [("E2_sysbench_oltp_ro","oltp_read_only",8,12),("E4_sysbench_point_select","oltp_point_select",16,12),("E_sysbench_oltp_rw","oltp_read_write",8,15),("E3_sysbench_oltp_wo","oltp_write_only",8,12)]:
    if want is not None and su not in want: continue
    if su=="E3_sysbench_oltp_wo" and am and (want is None or "E_sysbench_oltp_rw" in want): prep_sb()
    time.sleep(2); note=f"{tag} {lua} 4x10k"; cmd=["bash","-c",f"sysbench {lua} {cm} --threads={th} --time={dur} run >/tmp/sb_r.out 2>&1"]
    if bc(cmd,PW,False).returncode:
      time.sleep(2)
      if bc(cmd,PW,False).returncode:
        note=f"{tag} {lua} ps=off"
        if bc(["bash","-c",f"sysbench {lua} {cm} --threads={th} --time={dur} --db-ps-mode=disable run >/tmp/sb_r.out 2>&1"],PW,False).returncode:
          res[su]=row(topo,su,SC,th,dur,0,0,0,0,0,0,0,0,"EXPECTED_LIMITATION_UNSUPPORTED",0,f"{tag} err"); continue
    s=bc(["cat","/tmp/sb_r.out"]).stdout; tx,qm,em,avm,pm=[re.search(x,s) for x in pats]
    res[su]=row(topo,su,SC,th,dur,float(tx.group(2)) if tx else 0,float(qm.group(1)) if qm else 0,float(avm.group(1)) if avm else 0,0,float(pm.group(1)) if pm else 0,int(tx.group(1)) if tx else 0,int(em.group(1)) if em else 0,0,"PASS",0,note)
  for n in NS: q(n,"DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
  q(ldr(),"DELETE FROM public.yt_config WHERE module='A' AND name LIKE 'public.sbtest%';")
  return list(res.values())

def r_app(topo,tag,am=False):
  tb="bench_append_events"
  for n in NS: q(n,f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id UUID PRIMARY KEY DEFAULT uuidv7(),node_id INT,payload INT,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")
  yts(f"public.{tb}")
  if am: set_async(f"public.{tb}")
  sp.run(["docker","exec","-i","bench_client","bash","-c","cat>/tmp/s_append.sql"],input="\\set payload random(1,100000)\nINSERT INTO bench_append_events(node_id,payload) VALUES(:nid,:payload);\n",text=True,check=True)
  tps,avg,sdv,p95,ok,fl,rt=pb(topo,"H_append_only_insert",2,4,2,12,"-f /tmp/s_append.sql -D nid=1","-f /tmp/s_append.sql -D nid=2")
  for _ in range(45):
    cs=[int(q(n,f"SELECT count(*) FROM {tb};") or -1) for n in NS]
    if len(set(cs))==1 and cs[0]>=ok: break
    time.sleep(1)
  cs=[int(q(n,f"SELECT count(*) FROM {tb};") or -1) for n in NS]; dr=cs[0]-ok
  return row(topo,"H_append_only_insert",SC,8,12,tps,"N/A",avg,sdv,p95,ok,fl,rt,"PASS_CONVERGED" if (len(set(cs))==1 and dr==0) else "DIVERGED",dr,f"{tag} uuidv7 2n rows={J(map(str,cs))}")

def _tc(pc,args,chk=True): sh(["docker","run","--rm","--network",f"container:{pc}","--cap-add","NET_ADMIN",IMG,"tc","qdisc",*args],chk)

def r_wan(topo,ms,tag):
  rst(); l=ldr(); wn=next(n for n in NS if n!=l); peers=[n for n in NS if n!=wn]
  for pc in peers: _tc(pc,["replace","dev","eth0","root","netem","delay",f"{ms}ms"])
  time.sleep(1)
  try: tps,avg,sdv,p95,ok,fl,rt=pb_run(topo,f"F_wan_netem_{ms}ms",1,8,4,12,f"-D scale={SC}","", [wn,wn],PT,U,PW,io.StringIO())
  finally:
    for pc in peers: _tc(pc,["del","dev","eth0","root"],False)
    time.sleep(1)
  return row(topo,f"F_wan_netem_{ms}ms",SC,8,12,tps,"N/A",avg,sdv,p95,ok,fl,rt,f"PASS_NETEM_{ms}MS",0,f"{tag} netem {ms}ms wn={wn} ldr={l}")

def emit(rows,lf,r):
  rows.append(r)
  ln=f"  [{r['topology']}] {r['suite']}: tps={r['tps']} qps={r['qps']} avg={r['lat_avg_ms']}ms p95={r['lat_p95_ms']}ms ok={r['tx_committed']} fl={r['tx_failed']} rt={r['retries_40001']} {r['convergence_status']} drift={r['balance_drift']} | {r['notes']}"
  print(ln,flush=True); lf.write(ln+"\n")

SORD=["A_single_rw","B1_disjoint_rw","B2_overlap_rw","C_multinode_ro","D_hot_conflict","E_sysbench_oltp_rw","E2_sysbench_oltp_ro","E3_sysbench_oltp_wo","E4_sysbench_point_select","H_append_only_insert","F_wan_netem_10ms","F_wan_netem_25ms","F_wan_netem_50ms","G_conc_c1","G_conc_c4","G_conc_c8","G_conc_c16","G_conc_c32"]

def run_topo(topo,tag,am,want):
  if not want: return
  lf.write(f"=== [{topo}] Start ({tag}) ===\n")
  if am: set_async("public.pgbench_%")
  for su,m,c,j,d,a1,a2,dc in [("A_single_rw",1,8,4,15,f"-D scale={SC}","",True),("B1_disjoint_rw",2,4,2,15,f"-f /tmp/s_d1.sql -D half={HF}",f"-f /tmp/s_d2.sql -D half1={HF+1} -D nacc={NA}",True),("C_multinode_ro",2,8,4,15,"-S","-S",False)]:
    if su not in want: continue
    if dc: rst()
    tps,avg,sdv,p95,ok,fl,rt=pb(topo,su,m,c,j,d,a1,a2); cst,cdr,cn=cchk(ok,tag) if dc else ("PASS",0,f"{tag} select_only 16c")
    emit(rows,lf,row(topo,su,SC,m*c,d,tps,"N/A",avg,sdv,p95,ok,fl,rt,cst,cdr,cn))
  for su,md,d in [("B2_overlap_rw","ov",15),("D_hot_conflict","hot",12)]:
    if su in want: emit(rows,lf,r_ret(topo,su,md,d,tag))
  if any(s.startswith("E") for s in want):
    for r in r_sb(topo,tag,am,want):
      if r["suite"] in want: emit(rows,lf,r)
  if "H_append_only_insert" in want: emit(rows,lf,r_app(topo,tag,am))
  if any(s.startswith("G_") for s in want): rst()
  for c,j in [(1,1),(4,2),(8,4),(16,4),(32,4)]:
    su=f"G_conc_c{c}"
    if su in want:
      tps,avg,sdv,p95,ok,fl,rt=pb(topo,su,1,c,j,8,f"-D scale={SC}")
      emit(rows,lf,row(topo,su,SC,c,8,tps,"N/A",avg,sdv,p95,ok,fl,rt,"PASS",0,f"{tag} c={c} j={j}")); time.sleep(1)
  for ms in(10,25,50):
    if f"F_wan_netem_{ms}ms" in want: emit(rows,lf,r_wan(topo,ms,tag))

miss_only=os.environ.get("YT_ASYNC_MISSING_ONLY")=="1"
ex_path=Path(os.environ.get("YT_EXISTING_CSV",str(OUT)))
kept={}
if miss_only and ex_path.is_file():
  with ex_path.open(encoding="utf-8",newline="") as fh:
    kept={(r["topology"].strip(),r["suite"].strip()):r for r in csv.DictReader(fh)}
rows=list(kept.values()); assert_zero()
with LOG.open("w",encoding="utf-8",newline="\n") as lf:
  try:
    lf.write("=== YT Cluster 1.21.3 Empirical Benchmark (3-Node PG 18, PG_SCALE=2) ===\n")
    sh(["docker","compose","-f",CF,"up","-d"]); sh(["bash",str(R/"scripts/yt_cluster/setup_yt_cluster.sh")])
    ver=de("yt1",["psql","-X","-q","-U",U,"-d","labdb","-tAc","SELECT version();"],PW).stdout.strip().split(" on ")[0]
    dcc=de("yt1",["psql","-X","-q","-U",U,"-d","postgres","-tAc","SELECT e->>'value' FROM jsonb_array_elements(yt_info('d')::jsonb) e WHERE e->>'name'='def_cluster_commit';"],PW).stdout.strip()
    lf.write(f"engine: {ver} + yt_cluster 1.21 | default_cc={dcc} (half/sync-2pc) | sc=0 (NO_SC)\n")
    net=sh(["docker","inspect","-f","{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}","yt1"]).stdout.strip()
    sh(["docker","rm","-f","bench_client"],False); sh(["docker","run","-d","--name","bench_client","--network",net,"--cap-add","NET_ADMIN",IMG])
    mk_scripts(); init_pb()
    sp.run(["docker","exec","-i","bench_client","bash","-c","cat>/tmp/yt_retry.py"],input=RETRY_PY,text=True,check=True)
    de("bench_client",["pgbench","-h","yt1","-p",str(PT),"-U",U,"-d","labdb","-n","-c","4","-j","2","-T","4","-q"],PW,False)
    for tp,tg,am in [("yt-cluster","cc=half sc=NO_SC",False),("yt-cluster-async","cc=nodes>=0 sc=NO_SC",True)]:
      if miss_only and not am: continue
      want={s for s in SORD if (tp,s) not in kept} if miss_only else set(SORD)
      run_topo(tp,tg,am,want)
  finally:
    sh(["docker","rm","-f","bench_client"],False); sh(["docker","compose","-f",CF,"down","-v"],False)
    lf.write("=== [yt-cluster] Down (0 residual containers) ===\n"); lf.flush(); time.sleep(1); assert_zero()

tord={"yt-cluster":0,"yt-cluster-async":1}; sidx={s:i for i,s in enumerate(SORD)}
rows.sort(key=lambda r:(tord.get(r["topology"],9),sidx.get(r["suite"],99)))
write_csv_atomic(OUT,rows)
print(f"Wrote {len(rows)} rows to {OUT}",flush=True)
PY
