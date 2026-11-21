"""Reset, sysbench, append-only, and WAN netem helpers for optimized PG benchmarks."""
from __future__ import annotations

import re
import subprocess as sp
import time

from bench_pg_lib import B, bc, bctl, de, pq, row, sh, wlog
from bench_pg_opt_common import LOGICAL_SUB, MULTI_WRITER, SINGLE_PRIMARY, pb_run_opt, ref_sub, wcnt_opt

YT_SYNC_CFG = "CgPIAQE="
YT_ASYNC_CFG = "CgcSAhACyAEB"


def _tc(pc: str, img: str, args: list[str], chk: bool = True) -> None:
    """Run tc qdisc inside a container network namespace."""
    sh(["docker", "run", "--rm", "--network", f"container:{pc}", "--cap-add", "NET_ADMIN", img, "tc", "qdisc", *args], chk)


def yt_setup_opt(hs: list[str], pt: int, u: str, pw: str, pat: str, yt_am: bool = False) -> None:
    """Register matching tables in yt_cluster and apply sync or async parallel config."""
    for h in hs:
        pq(h, pt, u, pw, f"SELECT count(*) FROM public.yt_setup('{pat}','',true,'public.yt_config');")
    time.sleep(2.5)
    cfg = YT_ASYNC_CFG if yt_am else YT_SYNC_CFG
    pq(hs[0], pt, u, pw, f"UPDATE public.yt_config SET value='{cfg}' WHERE module='A' AND name LIKE '{pat}';")
    time.sleep(2.5)


def reset_ds_opt(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    """Reset pgbench balances and history and drain replication cleanly."""
    rst = f"UPDATE {B}accounts SET abalance=0 WHERE abalance<>0;UPDATE {B}branches SET bbalance=0;UPDATE {B}tellers SET tbalance=0;TRUNCATE {B}history"
    if t == "bucardo":
        bctl("stop")
        sql = f"{rst};DO $$ DECLARE r RECORD; BEGIN FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='bucardo' AND tablename LIKE 'delta_public_{B}%' LOOP EXECUTE 'TRUNCATE bucardo.'||quote_ident(r.tablename); END LOOP; END $$;"
        for h in hs:
            pq(h, pt, u, pw, sql)
        bctl("start")
        return
    if t.startswith("yt-cluster"):
        for h in hs:
            pq(h, pt, u, pw, f"BEGIN;SET LOCAL session_replication_role=replica;{rst};COMMIT;")
        time.sleep(0.5)
        return
    if t == "pgedge" and len(hs) > 1:
        for _ in range(30):
            cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(cnts)) == 1:
                break
            time.sleep(1)
    pq(hs[0], pt, u, pw, rst + ";")
    if len(hs) > 1 and not t.startswith(("citus", "yugabyte", "cockroach")):
        time.sleep(1)
        for n in hs[1:]:
            wcnt_opt(n, pt, u, pw, f"{B}history", 0, to_s=120)


def _drop_sb_sub(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    """Drop sysbench tables cleanly and refresh logical/bi-dir subscriptions."""
    pq(hs[1], pt, u, pw, "DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
    ref_sub(hs[1], pt, u, pw, LOGICAL_SUB[t])
    if t in ("pg-birep", "pg18-birep"):
        ref_sub(hs[0], pt, u, pw, "sub_from_node2")


def _sb_cleanup(t: str, hs: list[str], pt: int, u: str, pw: str, cm: str) -> None:
    """Clean up sysbench tables and cluster replication metadata."""
    bc(["bash", "-c", f"sysbench oltp_read_write {cm} cleanup >/dev/null 2>&1||true"])
    if t == "citus":
        for i in range(1, 5):
            pq(hs[0], pt, u, pw, f"DROP TABLE IF EXISTS sbtest{i} CASCADE;")
    elif t.startswith("yt-cluster"):
        for h in hs:
            pq(h, pt, u, pw, "DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
        pq(hs[0], pt, u, pw, "DELETE FROM public.yt_config WHERE module='A' AND name LIKE 'public.sbtest%';")
        time.sleep(1.5)
    elif t in LOGICAL_SUB:
        _drop_sb_sub(t, hs, pt, u, pw)


def _sb_prepare(t: str, hs: list[str], pt: int, u: str, pw: str, cm: str, sb_sz: int, yt_am: bool) -> int:
    """Prepare sysbench 4xN schema and distribute or replicate across cluster nodes."""
    h1 = hs[0]
    _sb_cleanup(t, hs, pt, u, pw, cm)
    if bc(["bash", "-c", f"sysbench oltp_read_write {cm} prepare >/tmp/sb_p.out 2>&1"], "", False).returncode:
        return 1
    if t == "citus":
        for i in range(1, 5):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('sbtest{i}','id');")
    elif t.startswith("yt-cluster"):
        dump = de(h1, ["pg_dump", "-U", u, "-d", "labdb", "-t", "sbtest*"], pw).stdout
        for h in hs[1:]:
            sp.run(["docker", "exec", "-i", "-e", f"PGPASSWORD={pw}", h, "psql", "-U", u, "-d", "labdb", "-v", "ON_ERROR_STOP=1"], input=dump, text=True, check=True, stdout=sp.DEVNULL)
        yt_setup_opt(hs, pt, u, pw, "public.sbtest%", yt_am)
    elif t in LOGICAL_SUB:
        dump = de(h1, ["pg_dump", "-U", u, "-d", "labdb", "-s", "-t", "sbtest*"], pw).stdout
        sp.run(["docker", "exec", "-i", "-e", f"PGPASSWORD={pw}", hs[1], "psql", "-U", u, "-d", "labdb", "-v", "ON_ERROR_STOP=1"], input=dump, text=True, check=True, stdout=sp.DEVNULL)
        ref_sub(hs[1], pt, u, pw, LOGICAL_SUB[t], "true")
        q = f"SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid JOIN pg_class c ON c.oid=r.srrelid WHERE s.subname='{LOGICAL_SUB[t]}' AND c.relname LIKE 'sbtest%' AND r.srsubstate='r';"
        for _ in range(30):
            if pq(hs[1], pt, u, pw, q) == "4":
                break
            time.sleep(1)
        if t in ("pg-birep", "pg18-birep"):
            ref_sub(hs[0], pt, u, pw, "sub_from_node2")
    elif len(hs) > 1 and not t.startswith(("yugabyte", "cockroach", "bucardo")):
        for n in hs[1:]:
            wcnt_opt(n, pt, u, pw, "sbtest4", sb_sz, to_s=180)
    return 0


def run_sysbench_opt(
    t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, suites: list[tuple], sb_sz: int = 25000, yt_am: bool = False, logf=None
) -> dict[str, dict]:
    """Prepare sysbench 4xN tables and run suites with Lua 40001/55409 retry hook."""
    pwa = f"--pgsql-password={pw} " if pw else ""
    cm = f"--db-driver=pgsql --pgsql-host={hs[0]} --pgsql-port={pt} --pgsql-user={u} {pwa}--pgsql-db=labdb --tables=4 --table-size={sb_sz}"
    is_yt = t.startswith("yt-cluster")
    if _sb_prepare(t, hs, pt, u, pw, cm, sb_sz, yt_am):
        err = "prep:" + bc(["head", "-n", "2", "/tmp/sb_p.out"], "", False).stdout.replace("\n", " ").strip()[:60]
        return {su: row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err) for su, _, th, dur, _ in suites}

    pats = (r"transactions:\s+(\d+)\s+\(([0-9.]+)", r"queries:\s+\d+\s+\(([0-9.]+)", r"ignored errors:\s+(\d+)", r"avg:\s+([0-9.]+)", r"95th percentile:\s+([0-9.]+)")
    res: dict[str, dict] = {}
    for su, lua, th, dur, wl in suites:
        if is_yt and yt_am and su == "E3_sysbench_oltp_wo" and "E_sysbench_oltp_rw" in res:
            _sb_prepare(t, hs, pt, u, pw, cm, sb_sz, yt_am)
        note = f"{lua} 4x{sb_sz // 1000}k"
        rc = bc(["bash", "-c", f"SB_LUA={lua} sysbench /tmp/sb_wrap.lua {cm} --threads={th} --time={dur} run >/tmp/sb_r.out 2>&1"], "", False).returncode
        if rc and is_yt:
            time.sleep(2)
            rc = bc(["bash", "-c", f"SB_LUA={lua} sysbench /tmp/sb_wrap.lua {cm} --threads={th} --time={dur} run >/tmp/sb_r.out 2>&1"], "", False).returncode
        if rc:
            note = f"{lua} ps=off"
            if bc(["bash", "-c", f"SB_LUA={lua} sysbench /tmp/sb_wrap.lua {cm} --threads={th} --time={dur} --db-ps-mode=disable run >/tmp/sb_r.out 2>&1"], "", False).returncode:
                err = "run:" + bc(["tail", "-n", "2", "/tmp/sb_r.out"], "", False).stdout.replace("\n", " ").strip()[:60]
                res[su] = row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err)
                continue
        s = bc(["cat", "/tmp/sb_r.out"]).stdout
        if wl and logf is not None:
            wlog(logf, s)
        tx, qm, em, am, pm = [re.search(x, s) for x in pats]
        ign = int(em.group(1)) if em else 0
        res[su] = row(t, su, sc, th, dur, float(tx.group(2)) if tx else 0, float(qm.group(1)) if qm else 0, float(am.group(1)) if am else 0, 0, float(pm.group(1)) if pm else 0, int(tx.group(1)) if tx else 0, 0, ign, "PASS", 0, note)

    time.sleep(2 if t in LOGICAL_SUB else 0)
    _sb_cleanup(t, hs, pt, u, pw, cm)
    return res


def run_append_only_opt(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, yt_am: bool = False) -> dict:
    """Create collision-free append-only table and measure H_append_only_insert."""
    tb, cols = "bench_append_events", "node_id INT NOT NULL,payload INT NOT NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP"
    if t == "bucardo":
        bctl("stop")
    if t in ("pg-birep", "bucardo", "pg18-birep", "pg17-logical", "pg18-logical") or t.startswith("yt-cluster"):
        for i, h in enumerate(hs, 1):
            if t == "pg18-birep" or t.startswith("yt-cluster"):
                ddl = f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id UUID PRIMARY KEY DEFAULT uuidv7(),{cols});"
            elif t in ("pg17-logical", "pg18-logical"):
                ddl = f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id BIGSERIAL PRIMARY KEY,{cols});"
            else:
                ddl = f"DROP TABLE IF EXISTS {tb} CASCADE;DROP SEQUENCE IF EXISTS {tb}_s CASCADE;CREATE SEQUENCE {tb}_s INCREMENT BY 2 START WITH {i};CREATE TABLE {tb}(ev_id BIGINT PRIMARY KEY DEFAULT nextval('{tb}_s'),{cols});"
            pq(h, pt, u, pw, ddl)
        if t == "bucardo":
            sh(["docker", "exec", "bucardo_daemon", "bash", "-lc", f"bucardo list sync|grep -q sync_append||bucardo add sync sync_append dbs=grp_mm tables=public.{tb} autokick=1 conflict_strategy=bucardo_latest"])
            sh(["docker", "exec", "bucardo_daemon", "bucardo", "update", "sync", "sync_append", "autokick=1", "stayalive=1", "kidsalive=1"])
            bctl("start")
        elif t.startswith("yt-cluster"):
            yt_setup_opt(hs, pt, u, pw, f"public.{tb}", yt_am)
        elif t in LOGICAL_SUB:
            ref_sub(hs[1], pt, u, pw, LOGICAL_SUB[t])
            if t in ("pg-birep", "pg18-birep"):
                ref_sub(hs[0], pt, u, pw, "sub_from_node2")
            time.sleep(2)
    else:
        pk = {"pgedge": f"ev_id BIGINT PRIMARY KEY DEFAULT snowflake.nextval('snowflake.id_seq'),{cols}", "citus": f"ev_id BIGSERIAL,{cols},PRIMARY KEY(payload,ev_id)", "cockroach": f"ev_id INT8 DEFAULT unique_rowid() PRIMARY KEY,{cols}", "cockroach-rc": f"ev_id INT8 DEFAULT unique_rowid() PRIMARY KEY,{cols}"}.get(t, f"ev_id BIGSERIAL PRIMARY KEY,{cols}")
        pq(hs[0], pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}({pk});")
        if t == "yugabyte":
            pq(hs[0], pt, u, pw, f"ALTER SEQUENCE {tb}_ev_id_seq CACHE 1000;")
        elif t == "citus":
            pq(hs[0], pt, u, pw, f"SELECT create_distributed_table('{tb}','payload');")
        elif len(hs) > 1 and not t.startswith("cockroach"):
            for n in hs[1:]:
                wcnt_opt(n, pt, u, pw, f"information_schema.tables WHERE table_name='{tb}'", 1)
    m = 2 if t in MULTI_WRITER else 1
    c, j = (4, 2) if m == 2 else (8, 4)
    tps, avg, sdv, p95, ok, fl, rt = pb_run_opt(t, "H_append_only_insert", m, c, j, 12, "-f /tmp/s_append.sql -D nid=1", "-f /tmp/s_append.sql -D nid=2", hs, pt, u, pw, None)
    if t == "bucardo":
        sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_append", "5"], False)
    if len(hs) > 1:
        for _ in range(60):
            cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
            if len(set(cnts)) == 1 and cnts[0] >= ok:
                break
            time.sleep(1)
    cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
    dr = cnts[0] - ok
    cst = ("PASS_SINGLE_PRIMARY" if t in SINGLE_PRIMARY else "PASS_CONVERGED") if (len(set(cnts)) == 1 and dr == 0) else "DIVERGED"
    return row(t, "H_append_only_insert", sc, 8, 12, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, dr, f"{m}n rows={'/'.join(map(str, cnts))}")


def run_wan_netem_opt(
    t: str, delay_ms: int, d: int, hs: list[str], pt: int, u: str, pw: str, sc: int, netem: list[str], img: str, warm_s: int = 5, logf=None, chk_hs: list[str] | None = None
) -> dict:
    """Inject tc netem delay on peers, warm up if configured, measure RW, and clean qdisc."""
    vhs = chk_hs or hs
    reset_ds_opt(t, vhs, pt, u, pw)
    for pc in netem:
        _tc(pc, img, ["replace", "dev", "eth0", "root", "netem", "delay", f"{delay_ms}ms"])
    time.sleep(1)
    try:
        if warm_s > 0:
            pb_run_opt(t, f"F_wan_netem_{delay_ms}ms", 1, 8, 4, warm_s, f"-D scale={sc}", "", hs, pt, u, pw, None)
            reset_ds_opt(t, vhs, pt, u, pw)
        tps, avg, sdv, p95, ok, fl, rt = pb_run_opt(t, f"F_wan_netem_{delay_ms}ms", 1, 8, 4, d, f"-D scale={sc}", "", hs, pt, u, pw, logf)
    finally:
        for pc in netem:
            _tc(pc, img, ["del", "dev", "eth0", "root"], False)
        time.sleep(1)
    return row(t, f"F_wan_netem_{delay_ms}ms", sc, 8, d, tps, "N/A", avg, sdv, p95, ok, fl, rt, f"PASS_NETEM_{delay_ms}MS", 0, f"tc netem {delay_ms}ms ({','.join(netem)})")
