"""Shared constants, runner wrappers, and CSV helpers for optimized PG benchmarks."""
from __future__ import annotations

import csv
import subprocess as sp
from pathlib import Path

from bench_pg_lib import (
    B, COLS, YT_RETRY_PY, assert_zero_containers, bc, conv_chk, mk_scripts,
    pb_run, pq, ref_sub as _ref_sub, row, sh, upsert_csv, wcnt, wlog,
)

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


def expected_suites(topo: str) -> list[str]:
    """Return expected suite list for a given topology."""
    if topo in STANDALONE_TOPOS:
        return [s for s in SUITE_ORDER if not s.startswith("F_wan_netem_")]
    return list(SUITE_ORDER)


def assert_zero_opt_containers() -> None:
    """Verify no lab or benchmark containers remain."""
    assert_zero_containers(OPT_PFX, ("yt1", "yt2", "yt3"), "Residual lab containers", sh_fn=sh)


def wcnt_opt(h: str, pt: int, u: str, pw: str, tbl: str, exp: int, to_s: int = 180) -> None:
    """Wait until table count reaches expected value or raise RuntimeError."""
    wcnt(h, pt, u, pw, tbl, exp, to_s=to_s)


def mk_scripts_opt() -> None:
    """Create pgbench, sysbench Lua retry, and YT retry scripts in bench_client."""
    mk_scripts()
    app = "\\set payload random(1,100000)\nINSERT INTO bench_append_events(node_id,payload) VALUES(:nid,:payload);\n"
    for path, content in (("/tmp/s_append.sql", app), ("/tmp/sb_wrap.lua", SB_RETRY_LUA), ("/tmp/yt_retry.py", YT_RETRY_PY)):
        sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", f"cat>{path}"], input=content, text=True, check=True)


def ref_sub(h: str, pt: int, u: str, pw: str, sub: str, cp: str = "false") -> None:
    """Refresh logical replication subscription publication."""
    _ref_sub(h, pt, u, pw, sub, cp, pq_fn=pq)


def pb_run_opt(t: str, su: str, m: int, c: int, j: int, d: int, a1: str, a2: str, hs: list[str], pt: int, u: str, pw: str, logf=None):
    """Run pgbench -M prepared with 200 retries and parse throughput and latency."""
    return pb_run(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf, prepared=True, max_tries=200, single_primary=SINGLE_PRIMARY, bc_fn=bc)


def conv_chk_opt(t: str, ok: int, hs: list[str], pt: int, u: str, pw: str) -> tuple[str, int, str]:
    """Wait for cross-node catch-up and compute balance drift status."""
    return conv_chk(t, ok, hs, pt, u, pw, single_primary=SINGLE_PRIMARY, wait_s=45, short_notes=True, pq_fn=pq, sh_fn=sh)


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
    upsert_csv(path, topo, new_rows, TOPO_ORDER, SUITE_ORDER)
