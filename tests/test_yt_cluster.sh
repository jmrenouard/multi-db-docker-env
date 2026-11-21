#!/usr/bin/env bash
# YT Cluster 1.21.3 live L1-L8, T11-T18, and T_REVERT suite.
set -euo pipefail
[ -f .env ] && { set -a; . ./.env; set +a; }
export YT_USER="${PG_USER:-postgres}" YT_DB="${PG_DB:-labdb}" YT_PASS="${PG_LAB_PASSWORD:-${DB_ROOT_PASSWORD:-pg_poc_ephemeral}}" YT_WITH_REVERT="${YT_WITH_REVERT:-0}" YT_CSV_OUT="${YT_CSV_OUT:-}" PYTHONDONTWRITEBYTECODE=1
for a in "$@"; do case "$a" in --with-revert) YT_WITH_REVERT=1 ;; --csv=*) YT_CSV_OUT="${a#--csv=}" ;; esac; done
exec python3 - <<'PY'
import csv,os,re,subprocess as sp,sys,threading as th,time
from pathlib import Path
E=os.environ; U,DB,PW,REV,CSV=E["YT_USER"],E["YT_DB"],E["YT_PASS"],E["YT_WITH_REVERT"]=="1",E["YT_CSV_OUT"]
N1,N2,N3="yt1","yt2","yt3"; NS=[N1,N2,N3]; SS=re.compile(r"ERROR:\s+([0-9A-Z]{5}):")
J,S,M,STS,R,C,P,F,EL="/".join,time.sleep,time.monotonic,set(),{},[0,0,0],"PASS","FAIL","EXPECTED_LIMITATION"
COLS="topology solution_name nodes cap_pacelc engine_version cluster_config f1_health aa_3node_convergence l1_serial_vs_uuidv7 l2_keyless_table l3_lost_update_balance l4_unique_email_conflict l5_ddl_and_savepoint l6_pg_features_extensions l7_node_outage_wal_backlog l8_majority_quorum_loss t11_bulk_10k t12_update_vs_delete t13_cross_node_fk_race t14_rich_data_fidelity t15_raw_visibility_lag_ms t16_sigkill_crash t17_long_open_tx t18_sequence_sync t_revert verified_sqlstates".split()

def dk(*a,chk=True,to=90):
 try: p=sp.run(["docker",*a],text=True,capture_output=True,timeout=to)
 except sp.TimeoutExpired:
  if chk: raise
  return sp.CompletedProcess(a,124,"","TO")
 if chk and p.returncode: raise RuntimeError(f"rc={p.returncode}")
 return p

def qr(n,s,db=DB,to=30,m=False):
 c=["docker","exec"]+(["-i"] if m else [])+["-e",f"PGPASSWORD={PW}",n,"psql","-Xq","-U",U,"-d",db,"-v","VERBOSITY=verbose","-v","ON_ERROR_STOP=1","-tA"]+([] if m else ["-c",s])
 try: p=sp.run(c,text=True,capture_output=True,timeout=to,**({"input":s+"\n"} if m else {}))
 except sp.TimeoutExpired: return 124,"","TO","TO"
 mo=SS.search(p.stderr); st=mo.group(1) if mo else ""
 if st: STS.add(st)
 return p.returncode,p.stdout.strip(),p.stderr.strip(),st

def q(n,s,db=DB,to=30):
 rc,o,e,_=qr(n,s,db,to)
 if rc: raise RuntimeError(f"{n}:{e[:40]}")
 return o

q1,q2,q3=lambda s,db=DB,to=30:q(N1,s,db,to),lambda s:q(N2,s),lambda s:q(N3,s)
K,W1="SELECT count(*) FROM "," WHERE id=1;"
vs=lambda s:[q(n,s) for n in NS]; cnt=lambda n,t:q(n,f"{K}yt_{t};"); vc=lambda t:[cnt(n,t) for n in NS]
I_=lambda t,v,c="":f"INSERT INTO yt_{t}{c} VALUES({v})"; ins=lambda n,t,v,c="":q(n,I_(t,v,c)+";"); U_=lambda t,s,w="id=1":f"UPDATE yt_{t} SET {s} WHERE {w}"
sel=lambda n,t,e,w="id=1":q(n,f"SELECT {e} FROM yt_{t} WHERE {w};"); vsel=lambda t,e,w="id=1":[sel(n,t,e,w) for n in NS]
so=lambda r:r[3] or "OK"; gs=lambda n,t,e,k,to=30:q(n,f"INSERT INTO yt_{t} SELECT {e} FROM generate_series(1,{k}) g;",to=to)

def weq(n,s,exp,to=25.0):
 t0=M()
 while M()-t0<to:
  rc,o,_,_=qr(n,s,to=8)
  if rc==0 and o==exp: return True,(M()-t0)*1000
  S(0.1)
 return False,(M()-t0)*1000

wc=lambda n,t,e,to=25.0:weq(n,f"{K}yt_{t};",str(e),to); wa=lambda t,e,to=20.0:[wc(n,t,e,to) for n in NS]; wal=lambda s,e,to=15.0:[weq(n,s,e,to) for n in NS]

def wcl(nodes=NS,to=90.0):
 t0=M()
 while M()-t0<to:
  ok,ldr=0,""
  for n in nodes:
   if dk("exec",n,"yt-health",chk=False,to=15).returncode: continue
   rc,o,_,_=qr(n,"SELECT yt_info('o')::text;","postgres",10)
   if rc==0 and "Leader" in o: ok+=1; ldr=n if ', Leader"' in o else ldr
  if ok==len(nodes) and ldr: return ldr
  S(1.5)
 raise RuntimeError(f"No leader")

def conc(s1,s2,d1=0.4,d2=0.2,g=0.05):
 o={}; qx=lambda s,d:f"BEGIN;{s};"+(f"SELECT pg_sleep({d});" if d else "")+"COMMIT;"
 ts=[th.Thread(target=lambda i=i,n=n,s=s,d=d:o.setdefault(i,qr(n,qx(s,d),m=True))) for i,n,s,d in((1,N1,s1,d1),(2,N2,s2,d2))]
 ts[0].start(); S(g); ts[1].start(); ts[0].join(); ts[1].join(); S(1); return so(o[1]),so(o[2])

def par(fn): ts=[th.Thread(target=fn,args=(n,)) for n in NS]; [t.start() for t in ts]; [t.join() for t in ts]
def rec(tag,i,msg): C[0 if tag==P else (2 if tag==EL else 1)]+=1; k=COLS[i]; R[k]=f"{tag}: {msg}"; print(f"[{tag}] {k}: {msg}",flush=True)
ldr=wcl(); ver,iom,chk=q1("SELECT version();").split(" on ")[0],q1("SHOW io_method;"),q1("SHOW data_checksums;")
ev,dcc,dsc,msz=q1("SELECT extversion FROM pg_extension WHERE extname='yt_cluster';"),q1("SELECT e->>'value' FROM jsonb_array_elements(yt_info('d')::jsonb) e WHERE e->>'name'='def_cluster_commit';","postgres"),q1("SELECT (yt_ct_decode('')::jsonb)->'value'->'Table'->>'sequential_consistency';"),q1("SELECT value FROM yt_config WHERE module='C' AND name='min_cluster_size';","postgres")
R["engine_version"],R["cluster_config"]=f"{ver} + yt_cluster {ev}",f"cc={dcc}(half) sc={dsc}(NO_SC) min={msz} io={iom} chk={chk}"
rec(P,6,f"3/3 ldr={ldr} {R['engine_version']} {R['cluster_config']}")

I,U7="id INT PRIMARY KEY","id UUID PRIMARY KEY DEFAULT uuidv7()"
SPEC="aa|U,src TX,d INT;s1|id SERIAL PRIMARY KEY,src TX;u1|U,src TX,sn INT;nk|a INT,b TX;l3|I,bal NUMERIC(12,2);l4|U,email TX UNIQUE,src TX;l5|I,v TX;l6|I,m yt_mood;l7|I,tag TX;eb|I,g INT,p TX;ep|I,nm TX;ec|id INT,pid INT REFERENCES yt_ep(id),PRIMARY KEY(pid,id);ef|I,j JSONB,b BYTEA,n TX,ts TIMESTAMPTZ,u TX;el|I,tok INT;es|id BIGINT PRIMARY KEY DEFAULT nextval('yt_es_seq'),tag TX"
TABS=[(a,b.replace("U,",U7+",").replace("I,",I+",").replace(" TX"," TEXT")) for a,b in(x.split("|") for x in SPEC.split(";"))]
DDL="DROP TABLE IF EXISTS "+",".join(f"yt_{t}" for t,_ in reversed(TABS))+" CASCADE;DROP SEQUENCE IF EXISTS yt_es_seq CASCADE;DROP TYPE IF EXISTS yt_mood CASCADE;CREATE TYPE yt_mood AS ENUM('ok','busy');CREATE SEQUENCE yt_es_seq START 1;"+"".join(f"CREATE TABLE yt_{t}({c});" for t,c in TABS)
for n in NS: qr(n,DDL,m=True); q(n,f"{K}yt_setup('public.yt_%','public.yt_config',true,'public.yt_config');")
S(2.5)
par(lambda n:[ins(n,"aa",f"'{n}',10","(src,d)") for _ in range(10)]); wa("aa",30); sm=vs("SELECT count(*)||':'||COALESCE(SUM(d),0) FROM yt_aa;")
rec(P if len(set(sm))==1 and sm[0]=="30:300" else F,7,f"30/30 sum=300({J(sm)})")
s1,s2=conc(I_("s1","'yt1'","(src)"),I_("s1","'yt2'","(src)"),0.4,0.4,0); sv=vs("SELECT COALESCE(string_agg(id||':'||src,',' ORDER BY id),'') FROM yt_s1;")
par(lambda n:[ins(n,"u1",f"'{n}',{i}","(src,sn)") for i in range(1,21)]); wa("u1",60,25)
inv=q1("WITH o AS (SELECT src,sn,id,lag(id) OVER (PARTITION BY src ORDER BY sn) p FROM yt_u1) SELECT count(*) FROM o WHERE p IS NOT NULL AND id<=p;")
rec(EL if (s1!="OK" or s2!="OK") else P,8,f"SER({s1}/{s2} {J(sv)}); u7 {J(vc('u1'))} inv={inv}")
ri=qr(N1,I_("nk","1,'init'")+";"); S(1); ci=vc("nk"); ru=qr(N1,U_("nk","b='upd'","a=1")+";"); S(1); cu=vsel("nk","COALESCE(min(b),'')","a=1")
rd=qr(N1,"DELETE FROM yt_nk WHERE a=1;"); S(1); cd=vc("nk"); rec(P if ci==["1"]*3 and cu==["upd"]*3 and cd==["0"]*3 else EL,9,f"i={so(ri)}({J(ci)}) u={so(ru)}({J(cu)}) d={so(rd)}({J(cd)})")
ins(N1,"l3","1,1000.00"); wal(f"SELECT bal::text FROM yt_l3{W1}","1000.00")
up,um=U_("l3","bal=bal+100"),U_("l3","bal=bal-30"); st1,st2=conc(up,um); bp=vsel("l3","bal::text")
rm=f"r1={so(qr(N1,up+';'))}" if st1!="OK" else (f"r2={so(qr(N2,um+';'))}" if st2!="OK" else "no"); S(1.2); bpo=vsel("l3","bal::text")
rec(P if len(set(bpo))==1 and bpo[0]=="1070.00" else EL,10,f"{st1}/{st2} pre={J(bp)} {rm} post={J(bpo)}")
u1,u2=conc(I_("l4","'dup@lab','yt1'","(email,src)"),I_("l4","'dup@lab','yt2'","(email,src)"),0.35,0.15)
ur=vsel("l4","count(*)||':'||COALESCE(min(src),'')","email='dup@lab'"); rec(P if len(set(ur))==1 and ur[0][:2]=="1:" and (u1!="OK" or u2!="OK") else EL,11,f"{u1}/{u2} {J(ur)}")
q1("INSERT INTO yt_l5 VALUES(1,'a'),(2,'b');"); wa("l5",2,15); ax="ALTER TABLE yt_l5 ADD COLUMN extra TEXT DEFAULT 'v1';"
q1(ax); S(1.2); cx=f"{K}pg_attribute WHERE attrelid='yt_l5'::regclass AND attname='extra';"; dc=vs(cx)
[q(n,ax) for n in(N2,N3) if q(n,cx)=="0"]; TR=lambda t:(q1(f"TRUNCATE yt_{t};"),S(1)); TR("l5"); tc=vc("l5")
spr=qr(N1,f"BEGIN;{I_('l5','10,chr(97)','(id,v)')};SAVEPOINT s1;{I_('l5','11,chr(98)','(id,v)')};ROLLBACK TO SAVEPOINT s1;COMMIT;",m=True)
rec(EL,12,f"ALT={J(dc)} TR={J(tc)} SP={so(spr)} r={cnt(N1,'l5')}")
lt=th.Thread(target=qr,args=(N1,"SELECT pg_advisory_lock(4242);SELECT pg_sleep(3);")); lt.start(); S(0.5); adv2=q2("SELECT pg_try_advisory_lock(4242);"); lt.join()
lnr={}; lnt=th.Thread(target=lambda:lnr.setdefault("o",qr(N2,"LISTEN ch_yt;SELECT pg_sleep(2.5);",m=True)[1])); lnt.start(); S(0.5); q1("NOTIFY ch_yt,'x';"); lnt.join()
tmpr=qr(N1,f"CREATE TEMP TABLE t_yt(x INT);INSERT INTO t_yt VALUES(1);{K}t_yt;",m=True); ins(N1,"l6","1,'busy'")
wal(f"SELECT m::text FROM yt_l6{W1}","busy"); rec(EL,13,f"adv={adv2} ln={'x' not in lnr.get('o','')} tmp={tmpr[0]} enum={J(vsel('l6','min(m::text)'))}")
dk("stop",N3); S(3); wcl([N1,N2],35); wok=sum(1 for i in range(1,11) if any(qr(N1 if i<=5 else N2,I_("l7",f"{i},'o{i}'")+";")[0]==0 or S(0.5) for _ in range(5)))
dk("start",N3); wcl(NS,65); c3ok,c3ms=wc(N3,"l7",10,30); rec(P if wok==10 and c3ok else F,14,f"1/3:{wok}/10 yt3={cnt(N3,'l7')}/10({c3ms:.0f}ms)")
dk("stop",N2,N3); S(6); qrc,_,_,qst=qr(N1,f"SET statement_timeout='5000';{I_('l7','999,chr(113)')};",to=10,m=True)
dk("start",N2,N3); wcl(NS,65); pr=qr(N1,I_("l7","1000,'ok'")+";"); wal(f"{K}yt_l7 WHERE id=1000;","1",20); rec(EL if qrc else P,15,f"2/3(min={msz}):{qst or qrc} post={so(pr)}")
t0=M(); gs(N1,"eb","g,g%10,repeat('x',64)",10000,240); dt=max(M()-t0,1e-4); ok2,lg2=wc(N2,"eb",10000,60); ok3,lg3=wc(N3,"eb",10000,60)
rec(P if ok2 and ok3 else F,16,f"{10000/dt:.0f}r/s({dt*1000:.0f}ms) yt2={lg2:.0f} yt3={lg3:.0f}")
TR("l5"); ins(N1,"l5","1,'init'","(id,v)"); wa("l5",1,15)
u12,d12=conc(U_("l5","v='upd_n1'"),f"DELETE FROM yt_l5{W1[:-1]}",0.4,0,0.1); v12=vsel("l5","COALESCE(min(v),'DEL')")
rec(P if len(set(v12))==1 else F,17,f"u={u12} d={d12} {J(v12)}")
fko,fke=0,{}
for i in range(100,110):
 ins(N1,"ep",f"{i},'p{i}'"); rc,_,_,st=qr(N2,I_("ec",f"{i},{i}","(id,pid)")+";")
 if rc==0: fko+=1
 else: fke[st or "E"]=fke.get(st or "E",0)+1
rec(P if not fke else EL,18,f"{fko}/10" if not fke else f"{fko}/10 {fke}")
ins(N1,"ef","1,'{\"k\":[1,true,null],\"nested\":{\"a\":\"ok\"}}'::jsonb,decode(repeat('deadbeef',16384),'hex'),NULL,'2026-11-19 12:34:56.789123+00'::timestamptz,chr(233)||chr(20013)||chr(128640)"); wa("ef",1,20)
hr=vsel("ef","octet_length(b)::text||'|'||md5(id::text||'|'||j::text||'|'||md5(encode(b,'hex'))||'|'||COALESCE(n,'<NULL>')||'|'||to_char(ts AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS.US')||'|'||md5(u))")
sz,h8=hr[0].split("|"); rec(P if len(set(hr))==1 and sz=="65536" else F,19,f"3/3 md5={h8[:8]} {sz}B")
lags=[]
for i in range(1,31):
 q1(f"INSERT INTO yt_el VALUES({i},{i}) ON CONFLICT(id) DO UPDATE SET tok=EXCLUDED.tok;"); t0=M()
 while True:
  rc,o,_,_=qr(N2,f"SELECT tok FROM yt_el WHERE id={i};",to=5)
  if rc==0 and o==str(i): lags.append((M()-t0)*1000); break
  if M()-t0>10: lags.append(1e4); break
  S(0.005)
lags.sort(); rec(P,20,f"p50={lags[15]:.2f} p95={lags[28]:.2f} max={lags[-1]:.2f}ms")
TR("l5"); ins(N1,"l5","1,'before'","(id,v)"); weq(N2,f"SELECT v FROM yt_l5{W1}","before",15)
th17=th.Thread(target=qr,args=(N1,"BEGIN;UPDATE yt_l5 SET v='c3s' WHERE id=1;SELECT pg_sleep(3);COMMIT;",DB,30,True))
th17.start(); S(0.6); ins(N1,"l5","2,'side'","(id,v)"); sok,sms=weq(N2,"SELECT v FROM yt_l5 WHERE id=2;","side",3.0)
mid=sel(N2,"l5","v"); th17.join(); aok,ams=weq(N2,f"SELECT v FROM yt_l5{W1}","c3s",15)
rec(P if mid=="before" and aok else F,22,f"{'NO_DIRTY' if mid=='before' else 'DIRTY'} side={sms:.0f}({sok}) post={ams:.0f}({aok})")
gs(N1,"es(tag)","'r_'||g",50); wc(N2,"es",50,20); lv2=q2("SELECT last_value||'|'||is_called FROM yt_es_seq;")
rc18,o18,_,st18=qr(N2,"INSERT INTO yt_es(tag) VALUES('fo') RETURNING id;"); rec(EL if rc18 else P,23,f"seq={lv2}->{st18}" if rc18 else f"seq={lv2} next={o18}")
TR("l7"); gs(N2,"l7","g,'c_'||g",20); dk("kill","-s","SIGKILL",N2); S(2); surv=int(cnt(N1,"l7")); wout="ERR"
for _ in range(8):
 rcw,_,_,stw=qr(N1,I_("l7","21,'out'")+";")
 if rcw==0: wout="OK"; break
 wout=f"ERR({stw})"; S(1)
dk("start",N2); pn=""
try: wcl(NS,25)
except RuntimeError:
 if "YT-E1104" in dk("logs","--tail","15",N2,chk=False).stdout: pn=";YT-E1104"; dk("exec",N2,"rm","-f","/var/run/postgresql/.s.YT.5432.pid",chk=False)
 wcl(NS,60)
if wout!="OK":
 for i in range(15):
  rcp,_,ep,_=qr(N1,I_("l7","21,'post'")+";")
  if rcp==0: break
  if i==14: raise RuntimeError(f"{N1}:{ep}")
  S(1)
ok16,ms16=wc(N2,"l7",21,35); rec(P if surv==20 and ok16 and not pn and wout=="OK" else (EL if surv==20 and ok16 else F),21,f"surv={surv}/20 RPO={20-surv} w={wout} post={cnt(N1,'l7')}/{cnt(N2,'l7')}({ms16:.0f}ms){pn}")
if REV:
 TR("l7"); gs(N1,"l7","g,'r_'||g",5); wc(N3,"l7",5,20); q3("DROP EXTENSION yt_cluster CASCADE;")
 el,tl,rk=q3(f"{K}pg_extension WHERE extname='yt_cluster';"),q3(f"{K}pg_trigger WHERE tgname LIKE 'zytsync_%';"),cnt(N3,"l7")
 prc,_,_,pst=qr(N3,I_("l7","6,'plain'")+";"); ra=cnt(N3,"l7"); rec(P if el=="0"==tl and rk=="5" and prc==0 and ra=="6" else F,24,f"ext={el} trig={tl} kept={rk}/5 plain={pst or 'OK'}({ra}/6)")
else: R["t_revert"]="SKIPPED"
R["verified_sqlstates"]=";".join(sorted(STS)) if STS else "NONE"; print(f"PASS={C[0]} FAIL={C[1]} EL={C[2]} ST={R['verified_sqlstates']}",flush=True)
if CSV:
 p=Path(CSV); p.parent.mkdir(parents=True,exist_ok=True)
 rd={"topology":"yt-cluster","solution_name":"YT Cluster 1.21.3 (PG 18.7)","nodes":"3 (yt1-3)","cap_pacelc":"CP-w/EL-r (half; NO_SC)",**{k:R.get(k,"") for k in COLS[4:]}}
 with p.open("w",encoding="utf-8",newline="\n") as fh: w=csv.DictWriter(fh,COLS,lineterminator="\n"); w.writeheader(); w.writerow(rd)
sys.exit(int(C[1]>0))
PY
