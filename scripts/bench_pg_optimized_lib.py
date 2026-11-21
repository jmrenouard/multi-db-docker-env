"""Optimized 18-topology dataset initialization and pgbench orchestration library."""
from __future__ import annotations

import time

from bench_pg_lib import B, COLS, bc, bctl, de, pq, row, sh, wlog
from bench_pg_opt_common import (
    CONC_LEVELS,
    LOGICAL_SUB,
    MULTI_WRITER,
    OPT_PFX,
    SB_RETRY_LUA,
    SINGLE_PRIMARY,
    STANDALONE_TOPOS,
    SUITE_ORDER,
    TOPO_ORDER,
    YT_RETRY_PY,
    assert_zero_opt_containers,
    completed_topologies,
    conv_chk_opt,
    expected_suites,
    mk_scripts_opt,
    pb_run_opt,
    ref_sub,
    upsert_opt_csv,
    wcnt_opt,
)
from bench_pg_opt_workloads import (
    YT_ASYNC_CFG,
    YT_SYNC_CFG,
    reset_ds_opt,
    run_append_only_opt,
    run_sysbench_opt,
    run_wan_netem_opt,
    yt_setup_opt,
)

__all__ = [
    "B", "COLS", "CONC_LEVELS", "LOGICAL_SUB", "MULTI_WRITER", "OPT_PFX",
    "SB_RETRY_LUA", "SINGLE_PRIMARY", "STANDALONE_TOPOS", "SUITE_ORDER", "TOPO_ORDER",
    "YT_ASYNC_CFG", "YT_RETRY_PY", "YT_SYNC_CFG",
    "assert_zero_opt_containers", "bc", "bctl", "completed_topologies", "conv_chk_opt",
    "de", "expected_suites", "init_ds_opt", "mk_scripts_opt", "pb_run_opt", "pq",
    "ref_sub", "reset_ds_opt", "row", "run_append_only_opt", "run_pb_suite_opt",
    "run_sysbench_opt", "run_wan_netem_opt", "run_yt_retry_opt", "sh", "upsert_opt_csv",
    "wcnt_opt", "wlog", "yt_leader", "yt_setup_opt",
]


def yt_leader(hs: list[str], u: str, pw: str) -> str:
    """Return the active YT Cluster Raft Leader container name."""
    for n in hs:
        out = de(n, ["psql", "-X", "-q", "-U", u, "-d", "postgres", "-tAc", "SELECT yt_info('o')::text;"], pw, False).stdout
        if ', Leader"' in out:
            return n
    return hs[0]


def _load_chunked(h: str, pt: int, u: str, pw: str, sc: int, is_crdb: bool = False, batch: int = 50000) -> None:
    """Load pgbench tables in bounded INSERT batches to prevent container OOM."""
    div, na = ("//" if is_crdb else "/"), 100000 * sc
    pq(h, pt, u, pw, f"INSERT INTO {B}branches(bid,bbalance,filler) SELECT g,0,repeat(' ',88) FROM generate_series(1,{sc}) g;")
    pq(h, pt, u, pw, f"INSERT INTO {B}tellers(tid,bid,tbalance,filler) SELECT g,(g-1){div}10+1,0,repeat(' ',84) FROM generate_series(1,{10*sc}) g;")
    for lo in range(1, na + 1, batch):
        hi = min(lo + batch - 1, na)
        pq(h, pt, u, pw, f"INSERT INTO {B}accounts(aid,bid,abalance,filler) SELECT g,(g-1){div}100000+1,0,repeat(' ',84) FROM generate_series({lo},{hi}) g;")
    pq(h, pt, u, pw, f"ANALYZE {B}branches; ANALYZE {B}tellers; ANALYZE {B}accounts;")


def init_ds_opt(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, na: int, yt_am: bool = False) -> None:
    """Initialize tuned pgbench schema and dataset across all 18 topologies."""
    h1, is_yb, is_crdb = hs[0], (t == "yugabyte"), t.startswith("cockroach")
    ff = "" if is_yb else " WITH (fillfactor=90)"
    pbi = ["pgbench", "-U", u, "-d", "labdb", "-i", "-s", str(sc), "-I", "g", "-n", "-q"]
    ddl = (
        f"CREATE TABLE {B}branches(bid INT PRIMARY KEY,bbalance INT,filler CHAR(88)){ff};"
        f"CREATE TABLE {B}tellers(tid INT PRIMARY KEY,bid INT,tbalance INT,filler CHAR(84)){ff};"
        f"CREATE TABLE {B}accounts(aid INT PRIMARY KEY,bid INT,abalance INT,filler CHAR(84)){ff};"
    )
    hc = "tid INT,bid INT,aid INT,delta INT,mtime TIMESTAMP,filler CHAR(22)"
    if t == "citus":
        for tbl in ("history", "accounts", "tellers", "branches"):
            pq(h1, pt, u, pw, f"DROP TABLE IF EXISTS {B}{tbl} CASCADE;")
        pq(h1, pt, u, pw, f"{ddl}CREATE TABLE {B}history(hid BIGSERIAL,{hc},PRIMARY KEY(aid,hid));")
        for tbl, col in (("branches", "bid"), ("tellers", "tid"), ("accounts", "aid")):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('{B}{tbl}','{col}');")
        pq(h1, pt, u, pw, f"SELECT create_distributed_table('{B}history','aid',colocate_with=>'{B}accounts');")
        bc([*pbi, "-h", h1, "-p", str(pt)], pw)
        return
    drop = f"DROP TABLE IF EXISTS {B}history,{B}accounts,{B}tellers,{B}branches CASCADE;"
    if t in ("pg-birep", "pg18-birep", "bucardo", "pg17-logical", "pg18-logical") or t.startswith("yt-cluster"):
        if t == "bucardo":
            bctl("stop")
            sh(["docker", "exec", "bucardo_daemon", "bucardo", "set", "quick_delta_check=1", "ctl_sleep=0.1", "kid_sleep=0.1"])
        for i, h in enumerate(hs, 1):
            if t == "pg18-birep" or t.startswith("yt-cluster"):
                hsql = f"CREATE TABLE {B}history(hid UUID PRIMARY KEY DEFAULT uuidv7(),{hc});"
            elif t in ("pg17-logical", "pg18-logical"):
                hsql = f"CREATE TABLE {B}history(hid BIGSERIAL PRIMARY KEY,{hc});"
            else:
                hsql = f"DROP SEQUENCE IF EXISTS {B}history_hid_seq CASCADE;CREATE SEQUENCE {B}history_hid_seq INCREMENT BY 2 START WITH {i};CREATE TABLE {B}history(hid BIGINT PRIMARY KEY DEFAULT nextval('{B}history_hid_seq'),{hc});"
            pq(h, pt, u, pw, f"{drop}{ddl}{hsql}")
            if t == "bucardo" or t.startswith("yt-cluster"):
                bc([*pbi, "-h", h, "-p", str(pt)], pw)
        if t == "bucardo":
            cmd = f"bucardo list sync|grep -q sync_pgbench||bucardo add sync sync_pgbench dbs=grp_mm tables=public.{B}branches,public.{B}tellers,public.{B}accounts,public.{B}history autokick=1 conflict_strategy=bucardo_latest"
            sh(["docker", "exec", "bucardo_daemon", "bash", "-lc", cmd])
            sh(["docker", "exec", "bucardo_daemon", "bucardo", "update", "sync", "sync_pgbench", "autokick=1", "stayalive=1", "kidsalive=1"])
            bctl("start")
        elif t.startswith("yt-cluster"):
            yt_setup_opt(hs, pt, u, pw, f"public.{B}%", yt_am)
        elif t in ("pg17-logical", "pg18-logical"):
            ref_sub(hs[1], pt, u, pw, LOGICAL_SUB[t])
            time.sleep(2)
            bc([*pbi, "-h", h1, "-p", str(pt)], pw)
            wcnt_opt(hs[1], pt, u, pw, f"{B}accounts", na, to_s=240)
        else:
            ref_sub(hs[0], pt, u, pw, "sub_from_node2")
            ref_sub(hs[1], pt, u, pw, "sub_from_node1")
            time.sleep(2)
            bc([*pbi, "-h", h1, "-p", str(pt)], pw)
            wcnt_opt(hs[1], pt, u, pw, f"{B}accounts", na, to_s=240)
        return
    hdef = {
        "pgedge": f"hid BIGINT PRIMARY KEY DEFAULT snowflake.nextval('snowflake.id_seq'),{hc}",
        "cockroach": f"hid INT8 DEFAULT unique_rowid() PRIMARY KEY,{hc}",
        "cockroach-rc": f"hid INT8 DEFAULT unique_rowid() PRIMARY KEY,{hc}",
    }.get(t, f"hid BIGSERIAL PRIMARY KEY,{hc}")
    pq(h1, pt, u, pw, f"{drop}{ddl}CREATE TABLE {B}history({hdef});")
    if is_yb:
        pq(h1, pt, u, pw, f"ALTER SEQUENCE {B}history_hid_seq CACHE 1000;")
    if t == "pgedge":
        for n in hs[1:]:
            wcnt_opt(n, pt, u, pw, f"information_schema.tables WHERE table_name='{B}history'", 1)
        pq(
            h1, pt, u, pw,
            f"ALTER TABLE {B}accounts ALTER COLUMN abalance SET (log_old_value=true,delta_apply_function=spock.delta_apply);"
            f"ALTER TABLE {B}branches ALTER COLUMN bbalance SET (log_old_value=true,delta_apply_function=spock.delta_apply);"
            f"ALTER TABLE {B}tellers ALTER COLUMN tbalance SET (log_old_value=true,delta_apply_function=spock.delta_apply);",
        )
        time.sleep(1)
    if is_yb or is_crdb:
        _load_chunked(h1, pt, u, pw, sc, is_crdb=is_crdb)
    else:
        bc([*pbi, "-h", h1, "-p", str(pt)], pw)
    if len(hs) > 1 and t in ("pg17-async-streaming", "pg17-sync-streaming", "pg18-async-streaming", "pg18-sync-streaming", "pgedge"):
        for n in hs[1:]:
            wcnt_opt(n, pt, u, pw, f"{B}accounts", na, to_s=240)


def run_pb_suite_opt(
    t: str, su: str, m: int, c: int, j: int, d: int, a1: str, a2: str,
    hs: list[str], pt: int, u: str, pw: str, sc: int,
    check_conv: bool = True, warm_s: int = 5, logf=None, chk_hs: list[str] | None = None,
) -> dict:
    """Run one pgbench -M prepared suite with optional warmup and convergence check."""
    vhs = chk_hs or hs
    if check_conv:
        reset_ds_opt(t, vhs, pt, u, pw)
    if warm_s > 0:
        pb_run_opt(t, su, m, c, j, warm_s, a1, a2, hs, pt, u, pw, None)
        if check_conv:
            reset_ds_opt(t, vhs, pt, u, pw)
    tps, avg, sdv, p95, ok, fl, rt = pb_run_opt(t, su, m, c, j, d, a1, a2, hs, pt, u, pw, logf)
    cst, cdr, cn = conv_chk_opt(t, ok, vhs, pt, u, pw) if check_conv else ("PASS", 0, f"m={m} c={m*c} j={j}")
    return row(t, su, sc, m * c, d, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, cdr, cn)


def run_yt_retry_opt(t: str, su: str, md: str, d: int, hs: list[str], pt: int, u: str, pw: str, sc: int, warm_s: int = 5) -> dict:
    """Run YT Cluster psycopg retry workload handling SQLSTATE 55409/40001/40P01."""
    na, targets = 100000 * sc, f"{hs[0]},{hs[1]}"
    if warm_s > 0:
        reset_ds_opt(t, hs, pt, u, pw)
        bc(["python3", "/tmp/yt_retry.py", md, str(warm_s), str(sc), str(na), pw, targets], "", False)
    reset_ds_opt(t, hs, pt, u, pw)
    p = bc(["python3", "/tmp/yt_retry.py", md, str(d), str(sc), str(na), pw, targets]).stdout.strip().split("|")
    cst, cdr, cn = conv_chk_opt(t, int(p[4]), hs, pt, u, pw)
    return row(t, su, sc, 8, d, float(p[0]), "N/A", float(p[1]), float(p[2]), float(p[3]), int(p[4]), int(p[5]), int(p[6]), cst, cdr, f"r40001={p[7]} r55409={p[8]} {cn}")
