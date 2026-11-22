#!/usr/bin/env bash
# Sequential V2 empirical benchmark runner across all 10 PostgreSQL topologies.
set -euo pipefail

export BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BENCH_ROOT"
[ -f .env ] && { set -a; . ./.env; set +a; }
export PYTHONDONTWRITEBYTECODE=1
export PG_SCALE="${PG_SCALE:-2}"
export PG_PASS="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
export DB_ROOT_PASSWORD="$PG_PASS"
export PG_LAB_PASSWORD="$PG_PASS"
export BENCH_IMAGE="${BENCH_IMAGE:-multi-db-pgbench-sysbench:latest}"
export BENCH_OUT_DIR="${BENCH_OUT_DIR:-${BENCH_ROOT}/reports/pg_benchmarks_v2}"

exec python3 - "$@" <<'PY'
import csv, os, sys, time
from contextlib import nullcontext
from pathlib import Path

R, OUT = Path(os.environ["BENCH_ROOT"]), Path(os.environ["BENCH_OUT_DIR"])
LOGD = OUT / "logs"
LOGD.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(R / "scripts"))

from bench_pg_lib import de, row, sh, wlog
from bench_pg_v2_lib import (
    SINGLE_PRIMARY, append_summary_preserving, assert_zero_poc_containers,
    conv_chk_v2, init_ds_v2, mk_scripts_v2, pb_run_v2, reset_ds_v2,
    run_append_only, run_sysbench_block, run_wan_netem, upsert_modular_csv,
)

SC = int(os.environ["PG_SCALE"])
NA, HF = 100000 * SC, 50000 * SC
PW, IMG = os.environ["PG_PASS"], os.environ["BENCH_IMAGE"]
SUMMARY_CSV, EXT_CSV = OUT / "benchmark_summary.csv", OUT / "benchmark_extended_workloads.csv"
WAN_CSV, CONC_CSV = OUT / "benchmark_wan_sweep.csv", OUT / "benchmark_concurrency_sweep.csv"

TOPO_ORDER = [
    "pg17-standalone", "pg17-async-streaming", "pg17-sync-streaming", "pg17-logical",
    "pg-birep", "pgedge", "bucardo", "citus", "yugabyte", "cockroach",
]
NEW_CORE = {"pg17-async-streaming", "pg17-logical"}
EXT_SUITES = ["E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo", "E4_sysbench_point_select", "H_append_only_insert"]
WAN_SUITES = ["F_wan_netem_10ms", "F_wan_netem_25ms", "F_wan_netem_50ms"]
CONC_LEVELS = [(1, 1), (4, 2), (8, 4), (16, 4), (32, 4)]
CONC_SUITES = [f"G_conc_c{c}" for c, _ in CONC_LEVELS]

SPEC = {
    "pg17-standalone": f"pg17-baseline||pg17_standalone|pg17_standalone|5432|postgres|{PW}|",
    "pg17-async-streaming": f"pg-streaming|scripts/pg_streaming/setup_pg_streaming.sh async||pg_stream_primary,pg_stream_standby|5432|postgres|{PW}|pg_stream_standby",
    "pg17-sync-streaming": f"pg17-baseline||pg17_sync_primary,pg17_sync_standby|pg17_sync_primary,pg17_sync_standby|5432|postgres|{PW}|pg17_sync_standby",
    "pg17-logical": f"pg-logical|scripts/pg_logical/setup_pg_logical.sh||pg_logical_pub,pg_logical_sub|5432|postgres|{PW}|pg_logical_sub",
    "pg-birep": f"pg-birep|scripts/pg_birep/setup_birep.sh||pg_birep_node1,pg_birep_node2|5432|postgres|{PW}|pg_birep_node2",
    "pgedge": f"pgedge|scripts/pgedge/setup_pgedge.sh||pgedge_node1,pgedge_node2,pgedge_node3|5432|postgres|{PW}|pgedge_node2,pgedge_node3",
    "bucardo": f"bucardo|scripts/bucardo/setup_bucardo.sh||bucardo_node1,bucardo_node2|5432|postgres|{PW}|bucardo_node2",
    "citus": f"citus|scripts/citus/setup_citus.sh||citus_coord|5432|postgres|{PW}|citus_worker1,citus_worker2",
    "yugabyte": "yugabyte|scripts/yugabyte/setup_yugabyte.sh||yb-node1,yb-node2,yb-node3|5433|yugabyte||yb_node2,yb_node3",
    "cockroach": "cockroach|scripts/cockroach/setup_cockroach.sh||crdb_node1,crdb_node2,crdb_node3|26257|root||crdb_node2,crdb_node3",
}


def load_wan25(topo: str) -> dict | None:
    """Read verified F_wan_netem_25ms row from benchmark_summary.csv if present."""
    if not SUMMARY_CSV.is_file():
        return None
    with SUMMARY_CSV.open(encoding="utf-8", newline="") as fh:
        for r in csv.DictReader(fh):
            if r["topology"] == topo and r["suite"] == "F_wan_netem_25ms":
                return dict(r)
    return None


def run_topo(t: str, logf=None) -> None:
    """Bring up one topology, run all required suites, and tear down cleanly."""
    assert_zero_poc_containers()
    cf_n, ss_cmd, sv_s, hs_s, pt_s, u, pw, ne_s = SPEC[t].split("|")
    svcs, hs, pt = [x for x in sv_s.split(",") if x], hs_s.split(","), int(pt_s)
    netem = [x for x in ne_s.split(",") if x]
    nc, cf, is_new = ("yb_node1" if t == "yugabyte" else hs[0]), str(R / f"docker-compose-{cf_n}.yml"), t in NEW_CORE
    core_rows, ext_rows, wan_rows, conc_rows = [], [], [], []
    try:
        if logf is not None:
            logf.write(f"=== [{t}] Start ===\n")
        sh(["docker", "compose", "-f", cf, "up", "-d", *svcs])
        if ss_cmd:
            out = sh(["bash", *ss_cmd.split()]).stdout
            if logf is not None:
                wlog(logf, out)
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
        mk_scripts_v2()
        init_ds_v2(t, hs, pt, u, pw, SC, NA)
        de("bench_client", ["pgbench", "-h", hs[0], "-p", str(pt), "-U", u, "-d", "labdb", "-n", "-c", "4", "-j", "2", "-T", "4", "-q"], pw, False)

        if is_new:
            hm = 1 if t in SINGLE_PRIMARY else (2 if len(hs) > 1 else 1)
            for su, m, c, j, d, a1, a2, dc in [
                ("A_single_rw", 1, 8, 4, 20, f"-D scale={SC}", "", True),
                ("B1_disjoint_rw", 2, 4, 2, 20, f"-f /tmp/s_d1.sql -D half={HF}", f"-f /tmp/s_d2.sql -D half1={HF+1} -D nacc={NA}", True),
                ("B2_overlap_rw", 2, 4, 2, 20, f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", True),
                ("C_multinode_ro", 2 if len(hs) > 1 else 1, 8 if len(hs) > 1 else 16, 4, 20, "-S", "-S", False),
                ("D_hot_conflict", hm, 4 if hm == 2 else 8, 2 if hm == 2 else 4, 15, "-f /tmp/s_hot.sql", "-f /tmp/s_hot.sql", True),
            ]:
                if dc:
                    reset_ds_v2(t, hs, pt, u, pw)
                tps, avg, sdv, p95, ok, fl, rt = pb_run_v2(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf)
                cst, cdr, cn = conv_chk_v2(t, ok, hs, pt, u, pw) if dc else ("PASS", 0, "select_only 16 clients")
                core_rows.append(row(t, su, SC, m * c, d, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, cdr, cn))
                print(f"  [{t}] {su}: tps={tps} avg={avg}ms p95={p95}ms {cst} drift={cdr}", flush=True)

        sb_plan = [("E2_sysbench_oltp_ro", "oltp_read_only", 8, 12, False), ("E4_sysbench_point_select", "oltp_point_select", 16, 12, False)]
        if is_new:
            sb_plan.append(("E_sysbench_oltp_rw", "oltp_read_write", 8, 20, True))
        sb_plan.append(("E3_sysbench_oltp_wo", "oltp_write_only", 8, 12, False))
        sb_res = run_sysbench_block(t, hs, pt, u, pw, SC, sb_plan, logf)
        if is_new:
            core_rows.append(sb_res["E_sysbench_oltp_rw"])
        for su in ("E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo", "E4_sysbench_point_select"):
            r = sb_res[su]
            ext_rows.append(r)
            print(f"  [{t}] {su}: tps={r['tps']} qps={r['qps']} p95={r['lat_p95_ms']}ms err={r['tx_failed']}", flush=True)

        h_row = run_append_only(t, hs, pt, u, pw, SC)
        ext_rows.append(h_row)
        print(f"  [{t}] H_append_only_insert: tps={h_row['tps']} p95={h_row['lat_p95_ms']}ms {h_row['convergence_status']} drift={h_row['balance_drift']}", flush=True)

        reset_ds_v2(t, hs, pt, u, pw)
        for c, j in CONC_LEVELS:
            su = f"G_conc_c{c}"
            tps, avg, sdv, p95, ok, fl, rt = pb_run_v2(t, su, 1, c, j, 8, f"-D scale={SC}", "", hs, pt, u, pw, None)
            conc_rows.append(row(t, su, SC, c, 8, tps, "N/A", avg, sdv, p95, ok, fl, rt, "PASS", 0, f"pgbench_rw c={c} j={j}"))
            print(f"  [{t}] {su}: tps={tps} avg={avg}ms p95={p95}ms ok={ok} fl={fl} rt={rt}", flush=True)
            time.sleep(1)

        if netem:
            w10 = run_wan_netem(t, 10, 12, hs, pt, u, pw, SC, netem, IMG, None)
            wan_rows.append(w10)
            print(f"  [{t}] F_wan_netem_10ms: tps={w10['tps']} avg={w10['lat_avg_ms']}ms p95={w10['lat_p95_ms']}ms rt={w10['retries_40001']}", flush=True)
            if is_new:
                w25 = run_wan_netem(t, 25, 15, hs, pt, u, pw, SC, netem, IMG, logf)
                core_rows.append(w25)
            else:
                w25 = load_wan25(t) or run_wan_netem(t, 25, 15, hs, pt, u, pw, SC, netem, IMG, None)
            wan_rows.append(w25)
            print(f"  [{t}] F_wan_netem_25ms: tps={w25['tps']} avg={w25['lat_avg_ms']}ms p95={w25['lat_p95_ms']}ms", flush=True)
            w50 = run_wan_netem(t, 50, 12, hs, pt, u, pw, SC, netem, IMG, None)
            wan_rows.append(w50)
            print(f"  [{t}] F_wan_netem_50ms: tps={w50['tps']} avg={w50['lat_avg_ms']}ms p95={w50['lat_p95_ms']}ms rt={w50['retries_40001']}", flush=True)
    finally:
        sh(["docker", "rm", "-f", "bench_client"], False)
        sh(["docker", "compose", "-f", cf, "down", "-v"], False)
        if logf is not None:
            logf.write(f"=== [{t}] Down ===\n")
        time.sleep(1)
        assert_zero_poc_containers()

    if is_new:
        append_summary_preserving(SUMMARY_CSV, t, core_rows)
    upsert_modular_csv(EXT_CSV, t, ext_rows, TOPO_ORDER, EXT_SUITES)
    upsert_modular_csv(CONC_CSV, t, conc_rows, TOPO_ORDER, CONC_SUITES)
    if wan_rows:
        upsert_modular_csv(WAN_CSV, t, wan_rows, TOPO_ORDER, WAN_SUITES)


arg = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("BENCH_TOPOLOGIES", "all")
for topo in (TOPO_ORDER if arg == "all" else [x.strip() for x in arg.split(",") if x.strip()]):
    if topo not in SPEC:
        raise SystemExit(f"Unknown topology: {topo}")
    print(f"=== Running V2 suite for {topo} ===", flush=True)
    with ((LOGD / f"{topo}.log").open("w", encoding="utf-8", newline="\n") if topo in NEW_CORE else nullcontext()) as logf:
        run_topo(topo, logf)
    print(f"=== Completed {topo} ===", flush=True)
PY
