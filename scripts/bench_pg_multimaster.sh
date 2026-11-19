#!/usr/bin/env bash
# Sequential empirical benchmark harness across 8 PostgreSQL topologies.
set -euo pipefail

export BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
export PG_SCALE="${PG_SCALE:-2}"
export PG_PASS="${PG_LAB_PASSWORD:-${DB_ROOT_PASSWORD:-pg_poc_ephemeral}}"
export BENCH_IMAGE="${BENCH_IMAGE:-multi-db-pgbench-sysbench:latest}"

exec python3 - "$@" <<'PY'
import csv, json, os, sys, time
from pathlib import Path

R = Path(os.environ["BENCH_ROOT"])
sys.path.insert(0, str(R / "scripts"))
from bench_pg_lib import B, COLS, bc, conv_chk, de, init_ds, mk_scripts, pb_run, pq, reset_ds, row, run_sb, sh, wlog

SC = int(os.environ["PG_SCALE"])
NA, HF = 100000 * SC, 50000 * SC
PW, IMG, ENVF = os.environ["PG_PASS"], os.environ["BENCH_IMAGE"], str(R / ".env.example")
MODE = "cps" if (R / "stacks").is_dir() else "mddb"
OUT = R / ("results" if MODE == "cps" else "reports/pg_benchmarks")
LOGD = OUT / "logs"
LOGD.mkdir(parents=True, exist_ok=True)
CSVP = OUT / "benchmark_summary.csv"

SPEC = {
    "pg17-standalone": f"pg17-baseline|pg17-baseline||pg17_standalone|pg17_standalone|5432|postgres|{PW}|",
    "pg17-sync-streaming": f"pg17-baseline|pg17-baseline||pg17_sync_primary,pg17_sync_standby|pg17_sync_primary,pg17_sync_standby|5432|postgres|{PW}|pg17_sync_standby",
    "pg-birep": f"pg-birep|pg-birep|setup_birep.sh||pg_birep_node1,pg_birep_node2|5432|postgres|{PW}|pg_birep_node2",
    "pgedge": f"pgedge-spock|pgedge|setup_pgedge.sh||pgedge_node1,pgedge_node2,pgedge_node3|5432|postgres|{PW}|pgedge_node2,pgedge_node3",
    "bucardo": f"bucardo|bucardo|setup_bucardo.sh||bucardo_node1,bucardo_node2|5432|postgres|{PW}|bucardo_node2",
    "citus": f"citus|citus|setup_citus.sh||citus_coord|5432|postgres|{PW}|citus_worker1,citus_worker2",
    "yugabyte": "yugabytedb|yugabyte|setup_yugabyte.sh||yb-node1,yb-node2,yb-node3|5433|yugabyte||yb_node2,yb_node3",
    "cockroach": "cockroachdb|cockroach|setup_cockroach.sh||crdb_node1,crdb_node2,crdb_node3|26257|root||crdb_node2,crdb_node3",
}


def run_topo(t):
    sd, cf_n, ss_r, sv_s, hs_s, pt_s, u, pw, ne_s = SPEC[t].split("|")
    svcs = [x for x in sv_s.split(",") if x]
    hs = hs_s.split(",")
    pt = int(pt_s)
    netem = [x for x in ne_s.split(",") if x]
    nc = "yb_node1" if t == "yugabyte" else hs[0]
    cf = str(R / "stacks" / sd / f"docker-compose-{cf_n}.yml") if MODE == "cps" else str(R / f"docker-compose-{cf_n}.yml")
    ss = (str(R / "scripts" / ss_r) if MODE == "cps" else str(R / "scripts" / ("pg_birep" if t == "pg-birep" else t) / ss_r)) if ss_r else ""
    rows = []
    with open(LOGD / f"{t}.log", "w", encoding="utf-8") as logf:
        logf.write(f"=== [{t}] Start ===\n")
        sh(["docker", "compose", "--env-file", ENVF, "-f", cf, "up", "-d", *svcs])
        try:
            if ss and Path(ss).is_file():
                wlog(logf, sh(["bash", ss]).stdout)
            else:
                for ck in ([nc] if t != "pg17-sync-streaming" else hs):
                    for _ in range(30):
                        if de(ck, ["pg_isready", "-U", u, "-d", "labdb"], pw, False).returncode == 0:
                            break
                        time.sleep(1)
                if t == "pg17-sync-streaming":
                    for q in ("ALTER SYSTEM SET synchronous_standby_names='pg17_sync_standby';", "ALTER SYSTEM SET synchronous_commit='on';", "SELECT pg_reload_conf();"):
                        de(nc, ["psql", "-U", u, "-d", "labdb", "-c", q], pw)
                    for _ in range(20):
                        if de(nc, ["psql", "-U", u, "-d", "labdb", "-tAc", "SELECT sync_state FROM pg_stat_replication WHERE application_name='pg17_sync_standby';"], pw).stdout.strip() == "sync":
                            break
                        time.sleep(1)
            net = sh(["docker", "inspect", "-f", "{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}", nc]).stdout.strip()
            sh(["docker", "rm", "-f", "bench_client"], False)
            sh(["docker", "run", "-d", "--name", "bench_client", "--network", net, "--cap-add", "NET_ADMIN", IMG])
            mk_scripts()
            init_ds(t, hs, pt, u, pw, SC, NA)
            bc(["pgbench", "-h", hs[0], "-p", str(pt), "-U", u, "-d", "labdb", "-n", "-c", "4", "-j", "2", "-T", "4", "-q"], pw, False)

            def rec(rn, su, m, c, j, d, a1, a2, dc=True):
                if dc:
                    reset_ds(t, hs, pt, u, pw)
                tps, avg, sdv, p95, ok, fl, rt = pb_run(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf)
                cst, cdr, cn = conv_chk(t, ok, hs, pt, u, pw) if dc else ("PASS", 0, "select_only 16 clients")
                rows.append(row(rn, su, SC, m * c, d, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, cdr, cn))

            hm = 2 if (len(hs) > 1 and t != "pg17-sync-streaming") else 1
            suites = [
                (t, "A_single_rw", 1, 8, 4, 20, f"-D scale={SC}", "", True),
                (t, "B1_disjoint_rw", 2, 4, 2, 20, f"-f /tmp/s_d1.sql -D half={HF}", f"-f /tmp/s_d2.sql -D half1={HF+1} -D nacc={NA}", True),
                (t, "B2_overlap_rw", 2, 4, 2, 20, f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", True),
                (t, "C_multinode_ro", 2 if len(hs) > 1 else 1, 8 if len(hs) > 1 else 16, 4, 20, "-S", "-S", False),
                (t, "D_hot_conflict", hm, 4 if hm == 2 else 8, 2 if hm == 2 else 4, 15, "-f /tmp/s_hot.sql", "-f /tmp/s_hot.sql", True),
            ]
            for rn, su, m, c, j, d, a1, a2, dc in suites:
                rec(rn, su, m, c, j, d, a1, a2, dc)
            if t == "pgedge":
                pq(hs[0], pt, u, pw, f"ALTER TABLE {B}accounts ALTER COLUMN abalance SET (log_old_value=true,delta_apply_function=spock.delta_apply);")
                rec("pgedge-delta-apply", "D_hot_conflict", 2, 4, 2, 15, "-f /tmp/s_hot.sql", "-f /tmp/s_hot.sql")
            rows.append(run_sb(t, hs[0], pt, u, pw, SC, logf))
            if netem:
                reset_ds(t, hs, pt, u, pw)
                for pc in netem:
                    sh(["docker", "run", "--rm", "--network", f"container:{pc}", "--cap-add", "NET_ADMIN", IMG, "tc", "qdisc", "replace", "dev", "eth0", "root", "netem", "delay", "25ms"])
                tps, avg, sdv, p95, ok, fl, rt = pb_run(t, "F_wan_netem_25ms", 1, 8, 4, 15, f"-D scale={SC}", "", hs, pt, u, pw, logf)
                for pc in netem:
                    sh(["docker", "run", "--rm", "--network", f"container:{pc}", "--cap-add", "NET_ADMIN", IMG, "tc", "qdisc", "del", "dev", "eth0", "root"], False)
                rows.append(row(t, "F_wan_netem_25ms", SC, 8, 15, tps, "N/A", avg, sdv, p95, ok, fl, rt, "PASS_NETEM_25MS", 0, f"tc netem 25ms ({','.join(netem)})"))
        finally:
            sh(["docker", "rm", "-f", "bench_client"], False)
            sh(["docker", "compose", "--env-file", ENVF, "-f", cf, "down", "-v"])
            logf.write(f"=== [{t}] Down ===\n")
    return rows


arg = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("BENCH_TOPOLOGIES", "all")
rlist = list(SPEC.keys()) if arg == "all" else arg.split(",")
rows = [] if (arg == "all" or not CSVP.exists()) else [r for r in csv.DictReader(CSVP.open(encoding="utf-8")) if r["topology"] not in set(rlist) and not (r["topology"] == "pgedge-delta-apply" and "pgedge" in rlist)]
for topo in rlist:
    print(f"Running {topo}...", flush=True)
    rows.extend(run_topo(topo))
    with CSVP.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLS)
        w.writeheader()
        w.writerows(rows)
    mid = len(rows) // 2
    (OUT / "benchmark_summary_part1.json").write_text(json.dumps(rows[:mid], separators=(",", ":")) + "\n", encoding="utf-8")
    (OUT / "benchmark_summary_part2.json").write_text(json.dumps(rows[mid:], separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Done {topo} ({len(rows)} rows).", flush=True)
PY
