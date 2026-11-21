#!/usr/bin/env bash
# Sequential production-tuned benchmark runner across all 18 PG/Multi-Master topologies.
set -euo pipefail

export BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
export PG_SCALE="${PG_SCALE:-20}"
export SB_TABLE_SIZE="${SB_TABLE_SIZE:-25000}"
export WARMUP_S="${WARMUP_S:-5}"
export PG_PASS="${PG_LAB_PASSWORD:-${DB_ROOT_PASSWORD:-pg_poc_ephemeral}}"
export DB_ROOT_PASSWORD="$PG_PASS"
export PG_LAB_PASSWORD="$PG_PASS"
export BENCH_IMAGE="${BENCH_IMAGE:-multi-db-pgbench-sysbench:latest}"
export BENCH_OUT_CSV="${BENCH_OUT_CSV:-${BENCH_ROOT}/reports/benchmark_optimized.csv}"
export BENCH_LOG_DIR="${BENCH_LOG_DIR:-${BENCH_ROOT}/reports/logs_optimized}"

cd "$BENCH_ROOT"

exec python3 - "$@" <<'PY'
import argparse
import os
import sys
import time
from pathlib import Path

R, OUT_CSV = Path(os.environ["BENCH_ROOT"]), Path(os.environ["BENCH_OUT_CSV"])
LOGD = Path(os.environ["BENCH_LOG_DIR"])
LOGD.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(R / "scripts"))

import bench_pg_optimized_lib as opt

SC, SB_SZ, WARM = int(os.environ["PG_SCALE"]), int(os.environ["SB_TABLE_SIZE"]), int(os.environ["WARMUP_S"])
NA, HF, PW, IMG = 100000 * SC, 50000 * SC, os.environ["PG_PASS"], os.environ["BENCH_IMAGE"]

# compose: (cf, setup, hs, pt, user, use_pw, svcs_extra, lb, netem)
SPEC = {
    "pg17-standalone": ("pg17-baseline", "", ["pg17_standalone"], 5432, "postgres", True, None, "", []),
    "pg17-async-streaming": ("pg-streaming", "scripts/pg_streaming/setup_pg_streaming.sh async", ["pg_stream_primary", "pg_stream_standby"], 5432, "postgres", True, None, "", ["pg_stream_standby"]),
    "pg17-sync-streaming": ("pg17-baseline", "", ["pg17_sync_primary", "pg17_sync_standby"], 5432, "postgres", True, None, "", ["pg17_sync_standby"]),
    "pg17-logical": ("pg-logical", "scripts/pg_logical/setup_pg_logical.sh", ["pg_logical_pub", "pg_logical_sub"], 5432, "postgres", True, None, "", ["pg_logical_sub"]),
    "pg-birep": ("pg-birep", "scripts/pg_birep/setup_birep.sh", ["pg_birep_node1", "pg_birep_node2"], 5432, "postgres", True, None, "", ["pg_birep_node2"]),
    "pg18-standalone": ("pg18-streaming", "", ["pg18_standalone"], 5432, "postgres", True, None, "", []),
    "pg18-async-streaming": ("pg18-streaming", "scripts/pg18_streaming/setup_pg18_streaming.sh async", ["pg18_stream_primary", "pg18_stream_standby"], 5432, "postgres", True, None, "", ["pg18_stream_standby"]),
    "pg18-sync-streaming": ("pg18-streaming", "scripts/pg18_streaming/setup_pg18_streaming.sh sync", ["pg18_stream_primary", "pg18_stream_standby"], 5432, "postgres", True, None, "", ["pg18_stream_standby"]),
    "pg18-logical": ("pg18-logical", "scripts/pg18_logical/setup_pg18_logical.sh", ["pg18_logical_pub", "pg18_logical_sub"], 5432, "postgres", True, None, "", ["pg18_logical_sub"]),
    "pg18-birep": ("pg18-birep", "scripts/pg18_birep/setup_pg18_birep.sh", ["pg18_birep_node1", "pg18_birep_node2"], 5432, "postgres", True, None, "", ["pg18_birep_node2"]),
    "pgedge": ("pgedge", "scripts/pgedge/setup_pgedge.sh", ["pgedge_node1", "pgedge_node2", "pgedge_node3"], 5432, "postgres", True, None, "", ["pgedge_node2", "pgedge_node3"]),
    "bucardo": ("bucardo", "scripts/bucardo/setup_bucardo.sh", ["bucardo_node1", "bucardo_node2"], 5432, "postgres", True, ["bucardo_node1", "bucardo_node2", "bucardo_daemon"], "", ["bucardo_node2"]),
    "citus": ("citus", "scripts/citus/setup_citus.sh", ["citus_coord"], 5432, "postgres", True, ["citus_coord", "citus_worker1", "citus_worker2"], "", ["citus_worker1", "citus_worker2"]),
    "yugabyte": ("yugabyte", "scripts/yugabyte/setup_yugabyte.sh", ["yb-node1", "yb-node2", "yb-node3"], 5433, "yugabyte", False, ["yb_node1", "yb_node2", "yb_node3", "haproxy_yugabyte"], "haproxy_yugabyte", ["yb_node2", "yb_node3"]),
    "cockroach": ("cockroach", "scripts/cockroach/setup_cockroach.sh", ["crdb_node1", "crdb_node2", "crdb_node3"], 26257, "root", False, ["crdb_node1", "crdb_node2", "crdb_node3", "haproxy_cockroach"], "haproxy_cockroach", ["crdb_node2", "crdb_node3"]),
    "cockroach-rc": ("cockroach", "scripts/cockroach/setup_cockroach.sh", ["crdb_node1", "crdb_node2", "crdb_node3"], 26257, "bench", False, ["crdb_node1", "crdb_node2", "crdb_node3", "haproxy_cockroach"], "haproxy_cockroach", ["crdb_node2", "crdb_node3"]),
    "yt-cluster": ("yt-cluster", "scripts/yt_cluster/setup_yt_cluster.sh", ["yt1", "yt2", "yt3"], 5432, "postgres", True, None, "", []),
    "yt-cluster-async": ("yt-cluster", "scripts/yt_cluster/setup_yt_cluster.sh", ["yt1", "yt2", "yt3"], 5432, "postgres", True, None, "", []),
}


def wait_pg(ct: str, u: str, pw: str) -> None:
    """Wait until PostgreSQL container accepts SQL queries."""
    for _ in range(45):
        if opt.de(ct, ["pg_isready", "-U", u, "-d", "labdb"], pw, False).returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for pg_isready on {ct}")


def wait_sql(h: str, pt: int, u: str, pw: str) -> None:
    """Poll SQL endpoint readiness up to 25s (e.g. HAProxy backend rise)."""
    for _ in range(25):
        try:
            if opt.pq(h, pt, u, pw, "SELECT 1;") == "1":
                return
        except Exception:
            pass
        time.sleep(1)
    raise RuntimeError(f"Timeout waiting for SQL endpoint {h}:{pt}")


def prep_special(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    """Apply runtime sync or Read Committed isolation settings."""
    if t == "pg17-sync-streaming":
        for q in ("ALTER SYSTEM SET synchronous_standby_names='pg17_sync_standby';", "ALTER SYSTEM SET synchronous_commit='on';", "SELECT pg_reload_conf();"):
            opt.de("pg17_sync_primary", ["psql", "-U", u, "-d", "labdb", "-c", q], pw)
        for _ in range(25):
            if opt.de("pg17_sync_primary", ["psql", "-U", u, "-d", "labdb", "-tAc", "SELECT sync_state FROM pg_stat_replication WHERE application_name='pg17_sync_standby';"], pw).stdout.strip() == "sync":
                return
            time.sleep(1)
        raise RuntimeError("pg17-sync-streaming failed to reach sync state")
    if t == "cockroach-rc":
        for q in ("SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true;", "CREATE USER IF NOT EXISTS bench;", "GRANT admin TO bench;", "ALTER ROLE bench SET default_transaction_isolation = 'read committed';"):
            opt.pq(hs[0], pt, "root", "", q)
        if opt.pq(hs[0], pt, u, "", "SHOW transaction_isolation;") != "read committed":
            raise RuntimeError("cockroach-rc failed to enforce read committed isolation")


def emit(rows: list[dict], logf, r: dict) -> None:
    """Record row and emit concise benchmark status line."""
    rows.append(r)
    ln = f"  [{r['topology']}] {r['suite']}: tps={r['tps']} qps={r['qps']} avg={r['lat_avg_ms']}ms p95={r['lat_p95_ms']}ms err={r['tx_failed']} rt={r['retries_40001']} {r['convergence_status']} drift={r['balance_drift']}"
    print(ln, flush=True)
    logf.write(ln + "\n")


def run_topo(t: str) -> None:
    """Provision one topology, execute all optimized suites, and clean up deterministically."""
    opt.assert_zero_opt_containers()
    cf_n, ss_cmd, hs, pt, u, use_pw, sv_ov, lb, netem = SPEC[t]
    hs, pw = list(hs), (PW if use_pw else "")
    svcs = list(sv_ov) if sv_ov is not None else hs
    netem, nc, cf = list(netem), ("yb_node1" if t == "yugabyte" else hs[0]), str(R / f"docker-compose-{cf_n}.yml")
    yt_am, is_yt, rows = (t == "yt-cluster-async"), t.startswith("yt-cluster"), []

    with (LOGD / f"{t}.log").open("w", encoding="utf-8", newline="\n") as logf:
        try:
            logf.write(f"=== [{t}] Start (PG_SCALE={SC}, SB={SB_SZ}, WARM={WARM}s) ===\n")
            opt.sh(["docker", "compose", "-f", cf, "up", "-d", *svcs])
            if ss_cmd:
                opt.sh(["bash", *ss_cmd.split()])
            else:
                for ck in ([nc] if t != "pg17-sync-streaming" else hs):
                    wait_pg(ck, u, pw)
            if is_yt:
                ldr = opt.yt_leader(hs, u, pw)
                flw = [n for n in hs if n != ldr]
                hs, netem = [ldr, *flw], [ldr, flw[1]]

            net = opt.sh(["docker", "inspect", "-f", "{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}", nc]).stdout.strip()
            opt.sh(["docker", "rm", "-f", "bench_client"], False)
            opt.sh(["docker", "run", "-d", "--name", "bench_client", "--network", net, "--cap-add", "NET_ADMIN", IMG])
            opt.mk_scripts_opt()
            prep_special(t, hs, pt, u, pw)
            if lb:
                wait_sql(lb, pt, u, pw)

            shost = [lb] if lb else [hs[0]]
            opt.init_ds_opt(t, hs, pt, u, pw, SC, NA, yt_am=yt_am)
            hm = 1 if t in opt.SINGLE_PRIMARY else 2
            emit(rows, logf, opt.run_pb_suite_opt(t, "A_single_rw", 1, 8, 4, 15, f"-D scale={SC}", "", shost, pt, u, pw, SC, True, WARM, logf, chk_hs=hs))
            emit(rows, logf, opt.run_pb_suite_opt(t, "B1_disjoint_rw", 2, 4, 2, 15, f"-f /tmp/s_d1.sql -D half={HF}", f"-f /tmp/s_d2.sql -D half1={HF+1} -D nacc={NA}", hs, pt, u, pw, SC, True, WARM, logf))
            if is_yt:
                emit(rows, logf, opt.run_yt_retry_opt(t, "B2_overlap_rw", "ov", 15, hs, pt, u, pw, SC, warm_s=WARM))
            else:
                emit(rows, logf, opt.run_pb_suite_opt(t, "B2_overlap_rw", 2, 4, 2, 15, f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", f"-f /tmp/s_ov.sql -D scale={SC} -D nacc={NA}", hs, pt, u, pw, SC, True, WARM, logf))
            emit(rows, logf, opt.run_pb_suite_opt(t, "C_multinode_ro", 2 if len(hs) > 1 else 1, 8 if len(hs) > 1 else 16, 4, 15, "-S", "-S", hs, pt, u, pw, SC, False, WARM, logf))
            if is_yt:
                emit(rows, logf, opt.run_yt_retry_opt(t, "D_hot_conflict", "hot", 12, hs, pt, u, pw, SC, warm_s=WARM))
            else:
                emit(rows, logf, opt.run_pb_suite_opt(t, "D_hot_conflict", hm, 4 if hm == 2 else 8, 2 if hm == 2 else 4, 12, "-f /tmp/s_hot.sql", "-f /tmp/s_hot.sql", hs, pt, u, pw, SC, True, WARM, logf))

            sb_plan = [("E2_sysbench_oltp_ro", "oltp_read_only", 8, 12, False), ("E4_sysbench_point_select", "oltp_point_select", 16, 12, False), ("E_sysbench_oltp_rw", "oltp_read_write", 8, 15, True), ("E3_sysbench_oltp_wo", "oltp_write_only", 8, 12, False)]
            sb_res = opt.run_sysbench_opt(t, [lb] if lb else hs, pt, u, pw, SC, sb_plan, sb_sz=SB_SZ, yt_am=yt_am, logf=logf)
            for su in ("E_sysbench_oltp_rw", "E2_sysbench_oltp_ro", "E3_sysbench_oltp_wo", "E4_sysbench_point_select"):
                emit(rows, logf, sb_res[su])
            emit(rows, logf, opt.run_append_only_opt(t, hs, pt, u, pw, SC, yt_am=yt_am))

            opt.reset_ds_opt(t, hs, pt, u, pw)
            for c, j in opt.CONC_LEVELS:
                emit(rows, logf, opt.run_pb_suite_opt(t, f"G_conc_c{c}", 1, c, j, 8, f"-D scale={SC}", "", shost, pt, u, pw, SC, False, WARM if c == 1 else 0, None))
                time.sleep(1)

            if netem:
                wan_hs = [hs[1]] if is_yt else [hs[0]]
                for ms in (10, 25, 50):
                    emit(rows, logf, opt.run_wan_netem_opt(t, ms, 12, wan_hs, pt, u, pw, SC, netem, IMG, warm_s=WARM, logf=logf if ms == 25 else None, chk_hs=hs))
        finally:
            opt.sh(["docker", "rm", "-f", "bench_client"], False)
            opt.sh(["docker", "compose", "-f", cf, "down", "-v"], False)
            logf.write(f"=== [{t}] Down ===\n")
            logf.flush()
            time.sleep(1)
            opt.assert_zero_opt_containers()

    opt.upsert_opt_csv(OUT_CSV, t, rows)


ap = argparse.ArgumentParser(description="Optimized 18-topology PG/Multi-Master benchmark runner.")
ap.add_argument("topo_pos", nargs="?", default=None, help="Topology list or 'all'.")
ap.add_argument("--topologies", default=None, help="Comma-separated topologies or 'all'.")
ap.add_argument("--resume", action="store_true", help="Skip topologies already complete in BENCH_OUT_CSV.")
ns = ap.parse_args()

raw = ns.topologies or ns.topo_pos or os.environ.get("BENCH_TOPOLOGIES", "all")
targets = opt.TOPO_ORDER if raw == "all" else [x.strip() for x in raw.split(",") if x.strip()]
done = opt.completed_topologies(OUT_CSV) if ns.resume else set()
for topo in targets:
    if topo not in SPEC:
        raise SystemExit(f"Unknown optimized topology: {topo}")
    if topo in done:
        print(f"=== Skipping completed {topo} (--resume) ===", flush=True)
        continue
    print(f"=== Running optimized benchmark suite for {topo} ===", flush=True)
    run_topo(topo)
    print(f"=== Completed {topo} ===", flush=True)
PY
