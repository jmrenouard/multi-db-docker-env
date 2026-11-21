#!/usr/bin/env bash
# Sequential empirical benchmark runner across all 5 native PostgreSQL 18 topologies.
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
export BENCH_OUT_DIR="${BENCH_OUT_DIR:-${BENCH_ROOT}/reports/pg18_benchmarks}"

exec python3 - "$@" <<'PY'
import os
import sys
import time
from pathlib import Path

R, OUT = Path(os.environ["BENCH_ROOT"]), Path(os.environ["BENCH_OUT_DIR"])
LOGD = OUT / "logs"
LOGD.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(R / "scripts"))

from bench_pg_lib import de, row, sh, wlog
from bench_pg18_lib import (
    SINGLE_PRIMARY, assert_zero_pg18_containers, conv_chk_pg18, init_ds_pg18,
    mk_scripts_pg18, pb_run_pg18, reset_ds_pg18, run_append_only_pg18,
    run_sysbench_pg18, run_wan_netem_pg18, upsert_pg18_csv,
)

SC = int(os.environ["PG_SCALE"])
NA, HF = 100000 * SC, 50000 * SC
PW, IMG = os.environ["PG_PASS"], os.environ["BENCH_IMAGE"]
OUT_CSV = OUT / "benchmark_pg18.csv"
LOG_FILE = LOGD / "pg18-benchmark.log"

TOPO_ORDER = [
    "pg18-standalone", "pg18-async-streaming", "pg18-sync-streaming",
    "pg18-logical", "pg18-birep",
]
SUITE_ORDER = [
    "A_single_rw", "B1_disjoint_rw", "B2_overlap_rw", "C_multinode_ro", "D_hot_conflict",
    "E_sysbench_oltp_rw", "E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo",
    "E4_sysbench_point_select", "H_append_only_insert",
    "F_wan_netem_10ms", "F_wan_netem_25ms", "F_wan_netem_50ms",
    "G_conc_c1", "G_conc_c4", "G_conc_c8", "G_conc_c16", "G_conc_c32",
]
CONC_LEVELS = [(1, 1), (4, 2), (8, 4), (16, 4), (32, 4)]

SPEC = {
    "pg18-standalone": f"pg18-streaming||pg18_standalone|pg18_standalone|5432|postgres|{PW}|",
    "pg18-async-streaming": f"pg18-streaming|scripts/pg18_streaming/setup_pg18_streaming.sh async|pg18_stream_primary,pg18_stream_standby|pg18_stream_primary,pg18_stream_standby|5432|postgres|{PW}|pg18_stream_standby",
    "pg18-sync-streaming": f"pg18-streaming|scripts/pg18_streaming/setup_pg18_streaming.sh sync|pg18_stream_primary,pg18_stream_standby|pg18_stream_primary,pg18_stream_standby|5432|postgres|{PW}|pg18_stream_standby",
    "pg18-logical": f"pg18-logical|scripts/pg18_logical/setup_pg18_logical.sh||pg18_logical_pub,pg18_logical_sub|5432|postgres|{PW}|pg18_logical_sub",
    "pg18-birep": f"pg18-birep|scripts/pg18_birep/setup_pg18_birep.sh||pg18_birep_node1,pg18_birep_node2|5432|postgres|{PW}|pg18_birep_node2",
}


def run_topo(t: str, logf) -> None:
    """Bring up one PG 18 topology, execute all benchmark suites, and tear down cleanly."""
    assert_zero_pg18_containers()
    cf_n, ss_cmd, sv_s, hs_s, pt_s, u, pw, ne_s = SPEC[t].split("|")
    svcs = [x for x in sv_s.split(",") if x]
    hs, pt = hs_s.split(","), int(pt_s)
    netem = [x for x in ne_s.split(",") if x]
    nc, cf = hs[0], str(R / f"docker-compose-{cf_n}.yml")
    rows = []
    try:
        logf.write(f"=== [{t}] Start ===\n")
        sh(["docker", "compose", "-f", cf, "up", "-d", *svcs])
        if ss_cmd:
            sh(["bash", *ss_cmd.split()])
        else:
            for _ in range(45):
                if de(nc, ["psql", "-U", u, "-d", "labdb", "-tAc", "SELECT 1;"], pw, False).stdout.strip() == "1":
                    break
                time.sleep(1)
        ver = de(nc, ["psql", "-U", u, "-d", "labdb", "-tAc", "SELECT version();"], pw).stdout.strip()
        iom = de(nc, ["psql", "-U", u, "-d", "labdb", "-tAc", "SHOW io_method;"], pw).stdout.strip()
        chk = de(nc, ["psql", "-U", u, "-d", "labdb", "-tAc", "SHOW data_checksums;"], pw).stdout.strip()
        logf.write(f"  env: {ver.split(' on ')[0]} | io_method={iom} | checksums={chk}\n")
        net = sh(["docker", "inspect", "-f", "{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}", nc]).stdout.strip()
        sh(["docker", "rm", "-f", "bench_client"], False)
        sh(["docker", "run", "-d", "--name", "bench_client", "--network", net, "--cap-add", "NET_ADMIN", IMG])
        mk_scripts_pg18()
        init_ds_pg18(t, hs, pt, u, pw, SC, NA)
        de("bench_client", ["pgbench", "-h", hs[0], "-p", str(pt), "-U", u, "-d", "labdb", "-n", "-c", "4", "-j", "2", "-T", "4", "-q"], pw, False)

        hm = 1 if t in SINGLE_PRIMARY else 2
        for su, m, c, j, d, a1, a2, dc in [
            ("A_single_rw", 1, 8, 4, 15, f"-D scale={SC}", "", True),
            ("B1_disjoint_rw", 2, 4, 2, 15, f"-f /tmp/s_d1.sql -D half={HF}", f"-f /tmp/s_d2.sql -D half1={HF+1} -D nacc={NA}", True),
            ("B2_overlap_rw", 2, 4, 2, 15, f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", True),
            ("C_multinode_ro", 2 if len(hs) > 1 else 1, 8 if len(hs) > 1 else 16, 4, 15, "-S", "-S", False),
            ("D_hot_conflict", hm, 4 if hm == 2 else 8, 2 if hm == 2 else 4, 12, "-f /tmp/s_hot.sql", "-f /tmp/s_hot.sql", True),
        ]:
            if dc:
                reset_ds_pg18(t, hs, pt, u, pw)
            tps, avg, sdv, p95, ok, fl, rt = pb_run_pg18(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, None)
            cst, cdr, cn = conv_chk_pg18(t, ok, hs, pt, u, pw) if dc else ("PASS", 0, "select_only 16c")
            rows.append(row(t, su, SC, m * c, d, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, cdr, cn))
            line = f"  [{t}] {su}: tps={tps} avg={avg}ms p95={p95}ms {cst} drift={cdr}"
            print(line, flush=True)
            logf.write(line + "\n")

        sb_plan = [
            ("E2_sysbench_oltp_ro", "oltp_read_only", 8, 12, False),
            ("E4_sysbench_point_select", "oltp_point_select", 16, 12, False),
            ("E_sysbench_oltp_rw", "oltp_read_write", 8, 15, False),
            ("E3_sysbench_oltp_wo", "oltp_write_only", 8, 12, False),
        ]
        sb_res = run_sysbench_pg18(t, hs, pt, u, pw, SC, sb_plan, None)
        for su in ("E_sysbench_oltp_rw", "E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo", "E4_sysbench_point_select"):
            r = sb_res[su]
            rows.append(r)
            line = f"  [{t}] {su}: tps={r['tps']} qps={r['qps']} p95={r['lat_p95_ms']}ms err={r['tx_failed']}"
            print(line, flush=True)
            logf.write(line + "\n")

        h_row = run_append_only_pg18(t, hs, pt, u, pw, SC)
        rows.append(h_row)
        line = f"  [{t}] H_append_only_insert: tps={h_row['tps']} p95={h_row['lat_p95_ms']}ms {h_row['convergence_status']} drift={h_row['balance_drift']}"
        print(line, flush=True)
        logf.write(line + "\n")

        reset_ds_pg18(t, hs, pt, u, pw)
        for c, j in CONC_LEVELS:
            su = f"G_conc_c{c}"
            tps, avg, sdv, p95, ok, fl, rt = pb_run_pg18(t, su, 1, c, j, 8, f"-D scale={SC}", "", hs, pt, u, pw, None)
            rows.append(row(t, su, SC, c, 8, tps, "N/A", avg, sdv, p95, ok, fl, rt, "PASS", 0, f"c={c} j={j}"))
            line = f"  [{t}] {su}: tps={tps} avg={avg}ms p95={p95}ms"
            print(line, flush=True)
            logf.write(line + "\n")
            time.sleep(1)

        if netem:
            for ms in (10, 25, 50):
                wr = run_wan_netem_pg18(t, ms, 12, hs, pt, u, pw, SC, netem, IMG, None)
                rows.append(wr)
                line = f"  [{t}] F_wan_netem_{ms}ms: tps={wr['tps']} avg={wr['lat_avg_ms']}ms p95={wr['lat_p95_ms']}ms"
                print(line, flush=True)
                logf.write(line + "\n")
    finally:
        sh(["docker", "rm", "-f", "bench_client"], False)
        sh(["docker", "compose", "-f", cf, "down", "-v"], False)
        logf.write(f"=== [{t}] Down ===\n")
        logf.flush()
        time.sleep(1)
        assert_zero_pg18_containers()

    upsert_pg18_csv(OUT_CSV, t, rows, TOPO_ORDER, SUITE_ORDER)


arg = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("BENCH_TOPOLOGIES", "all")
targets = TOPO_ORDER if arg == "all" else [x.strip() for x in arg.split(",") if x.strip()]
mode = "w" if arg == "all" else "a"
with LOG_FILE.open(mode, encoding="utf-8", newline="\n") as lf:
    for topo in targets:
        if topo not in SPEC:
            raise SystemExit(f"Unknown PG 18 topology: {topo}")
        print(f"=== Running PG 18 benchmark suite for {topo} ===", flush=True)
        run_topo(topo, lf)
        print(f"=== Completed {topo} ===", flush=True)
PY
