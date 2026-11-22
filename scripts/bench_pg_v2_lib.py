"""Helper routines for the V2 PostgreSQL empirical benchmark suite."""
from __future__ import annotations

import csv, io, re, shlex, subprocess as sp, time
from pathlib import Path

from bench_pg_lib import (
    B, COLS, assert_zero_containers, bc, bctl, conv_chk, drop_sb_sub, init_ds, mk_scripts,
    pb_run, pq, ref_sub, reset_ds, row, run_wan_netem as _run_wan_netem, sh, tc_netem,
    upsert_csv, wait_sub_ready, wait_wal_replay, wcnt, wlog,
)

SINGLE_PRIMARY = {"pg17-async-streaming", "pg17-sync-streaming", "pg17-logical"}
MULTI_WRITER = {"pg-birep", "pgedge", "bucardo", "yugabyte", "cockroach"}
POC_PFX = (
    "pg17_", "pg_stream_", "pg_logical_", "pg_birep_", "haproxy_pg_",
    "pgedge_", "haproxy_pgedge", "bucardo_", "citus_", "yb_", "crdb_", "bench_client",
)


def assert_zero_poc_containers() -> None:
    """Verify no PoC containers remain."""
    assert_zero_containers(POC_PFX, label="Residual PoC containers", sh_fn=sh)


def mk_scripts_v2() -> None:
    """Generate V1 pgbench scripts plus append-only insert script."""
    mk_scripts()
    app = "\\set payload random(1,100000)\nINSERT INTO bench_append_events(node_id,payload) VALUES(:nid,:payload);\n"
    sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", "cat>/tmp/s_append.sql"], input=app, text=True, check=True)


def init_ds_v2(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, na: int) -> None:
    """Initialize pgbench tables across all 10 topologies."""
    if t == "pg17-logical":
        ddl = (
            f"DROP TABLE IF EXISTS {B}history,{B}accounts,{B}tellers,{B}branches CASCADE;"
            f"CREATE TABLE {B}branches(bid INT PRIMARY KEY,bbalance INT,filler CHAR(88));"
            f"CREATE TABLE {B}tellers(tid INT PRIMARY KEY,bid INT,tbalance INT,filler CHAR(84));"
            f"CREATE TABLE {B}accounts(aid INT PRIMARY KEY,bid INT,abalance INT,filler CHAR(84));"
            f"CREATE TABLE {B}history(hid BIGSERIAL PRIMARY KEY,tid INT,bid INT,aid INT,delta INT,mtime TIMESTAMP,filler CHAR(22));"
        )
        for h in hs:
            pq(h, pt, u, pw, ddl)
        _ref(hs[1], pt, u, pw, "sub_logical")
        time.sleep(2)
        bc(["pgbench", "-U", u, "-d", "labdb", "-i", "-s", str(sc), "-I", "g", "-n", "-q", "-h", hs[0], "-p", str(pt)], pw)
        wcnt(hs[1], pt, u, pw, f"{B}accounts", na)
        return
    init_ds(t, hs, pt, u, pw, sc, na)
    if t in ("pg17-async-streaming", "pg17-sync-streaming") and len(hs) > 1:
        wcnt(hs[1], pt, u, pw, f"{B}accounts", na)


def reset_ds_v2(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    """Reset pgbench tables and wait for replica catchup."""
    reset_ds(t, hs, pt, u, pw)
    if t in SINGLE_PRIMARY and len(hs) > 1:
        time.sleep(1)
        wcnt(hs[1], pt, u, pw, f"{B}history", 0)


def pb_run_v2(t: str, su: str, m: int, c: int, j: int, d: int, a1: str, a2: str, hs: list[str], pt: int, u: str, pw: str, logf=None):
    """Run pgbench via V1 parser with single-primary routing."""
    eff = [hs[0], hs[0]] if (m > 1 and t in SINGLE_PRIMARY and su != "C_multinode_ro") else hs
    return pb_run(t, su, m, c, j, d, a1, a2, eff, pt, u, pw, logf if logf is not None else io.StringIO())


def conv_chk_v2(t: str, ok: int, hs: list[str], pt: int, u: str, pw: str):
    """Wait for async/logical catchup before V1 convergence check."""
    if t in ("pg17-async-streaming", "pg17-logical") and len(hs) > 1:
        for _ in range(30):
            hcs = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(hcs)) == 1 and hcs[0] >= ok:
                break
            time.sleep(1)
    return conv_chk(t, ok, hs, pt, u, pw)


def _ref(h, pt, u, pw, sub, cp="false"):
    ref_sub(h, pt, u, pw, sub, cp, pq_fn=pq)


def _drop_sb_sub(t, hs, pt, u, pw):
    sub = "sub_logical" if t == "pg17-logical" else "sub_from_node1"
    drop_sb_sub(hs, pt, u, pw, sub, t == "pg-birep", pq_fn=pq)


def _sb_cmd(lua, cm, tail, pw=""):
    return bc(["bash", "-c", f"sysbench {lua} {cm} {tail}"], pw, False).returncode


def run_sysbench_block(t, hs, pt, u, pw, sc, suites, logf=None):
    """Prepare sysbench once and run requested OLTP suites."""
    h1, pwa = hs[0], ('--pgsql-password="$PGPASSWORD" ' if pw else "")
    cm = f"--db-driver=pgsql --pgsql-host={shlex.quote(str(h1))} --pgsql-port={pt} --pgsql-user={shlex.quote(str(u))} {pwa}--pgsql-db=labdb --tables=4 --table-size=10000"
    _sb_cmd("oltp_read_write", cm, "cleanup >/dev/null 2>&1||true", pw)
    if t in ("pg17-logical", "pg-birep"):
        _drop_sb_sub(t, hs, pt, u, pw)
    res = {}
    if _sb_cmd("oltp_read_write", cm, "prepare >/tmp/sb_p.out 2>&1", pw):
        err = "prepare: " + bc(["head", "-n", "4", "/tmp/sb_p.out"], "", False).stdout.replace("\n", " ").strip()
        return {su: row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err) for su, _, th, dur, _ in suites}
    if t == "citus":
        for i in range(1, 5):
            pq(h1, pt, u, pw, f"SELECT create_distributed_table('sbtest{i}','id');")
    elif t in ("pg17-logical", "pg-birep"):
        sub = "sub_logical" if t == "pg17-logical" else "sub_from_node1"
        bc(["bash", "-c", f"pg_dump -h {shlex.quote(str(h1))} -p {pt} -U {shlex.quote(str(u))} -d labdb -s -t 'sbtest*' | psql -h {shlex.quote(str(hs[1]))} -p {pt} -U {shlex.quote(str(u))} -d labdb -v ON_ERROR_STOP=1 >/dev/null"], pw)
        _ref(hs[1], pt, u, pw, sub, "true")
        wait_sub_ready(hs[1], pt, u, pw, sub, pq_fn=pq)
        if t == "pg-birep":
            _ref(hs[0], pt, u, pw, "sub_from_node2")
    elif t in ("pg17-async-streaming", "pg17-sync-streaming", "pgedge") and len(hs) > 1:
        wcnt(hs[1], pt, u, pw, "sbtest4", 10000)
    pats = (r"transactions:\s+(\d+)\s+\(([0-9.]+)", r"queries:\s+\d+\s+\(([0-9.]+)", r"ignored errors:\s+(\d+)", r"avg:\s+([0-9.]+)", r"95th percentile:\s+([0-9.]+)")
    for su, lua, th, dur, wl in suites:
        note = f"{lua} tables=4 size=10000"
        if _sb_cmd(lua, cm, f"--threads={th} --time={dur} run >/tmp/sb_r.out 2>&1", pw):
            note = f"{lua} --db-ps-mode=disable"
            if _sb_cmd(lua, cm, f"--threads={th} --time={dur} --db-ps-mode=disable run >/tmp/sb_r.out 2>&1", pw):
                err = "run: " + bc(["tail", "-n", "4", "/tmp/sb_r.out"], "", False).stdout.replace("\n", " ").strip()
                res[su] = row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err)
                continue
        s = bc(["cat", "/tmp/sb_r.out"]).stdout
        if wl and logf is not None:
            wlog(logf, s)
        tx, qm, em, am, pm = [re.search(x, s) for x in pats]
        res[su] = row(t, su, sc, th, dur, float(tx.group(2)) if tx else 0, float(qm.group(1)) if qm else 0, float(am.group(1)) if am else 0, 0, float(pm.group(1)) if pm else 0, int(tx.group(1)) if tx else 0, int(em.group(1)) if em else 0, 0, "PASS", 0, note)
    _sb_cmd("oltp_read_write", cm, "cleanup >/dev/null 2>&1||true", pw)
    if t in ("pg17-logical", "pg-birep"):
        wait_wal_replay(hs[0], pt, u, pw, pq_fn=pq)
        _drop_sb_sub(t, hs, pt, u, pw)
    return res


def run_append_only(t, hs, pt, u, pw, sc):
    """Create collision-free append-only table and run H_append_only_insert."""
    tb, cols = "bench_append_events", "node_id INT NOT NULL,payload INT NOT NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP"
    if t in ("pg-birep", "bucardo"):
        if t == "bucardo":
            bctl("stop")
        for i, h in enumerate(hs, 1):
            pq(h, pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;DROP SEQUENCE IF EXISTS {tb}_s CASCADE;CREATE SEQUENCE {tb}_s INCREMENT BY 2 START WITH {i};CREATE TABLE {tb}(ev_id BIGINT PRIMARY KEY DEFAULT nextval('{tb}_s'),{cols});")
        if t == "pg-birep":
            for n, s in ((hs[0], "2"), (hs[1], "1")):
                _ref(n, pt, u, pw, f"sub_from_node{s}")
            time.sleep(2)
        else:
            sh(["docker", "exec", "bucardo_daemon", "bash", "-lc", f"bucardo list sync|grep -q sync_append||bucardo add sync sync_append dbs=grp_mm tables=public.{tb} conflict_strategy=bucardo_latest"])
            bctl("start")
    elif t == "pg17-logical":
        for h in hs:
            pq(h, pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id BIGSERIAL PRIMARY KEY,{cols});")
        _ref(hs[1], pt, u, pw, "sub_logical")
        time.sleep(2)
    else:
        pk = {"pgedge": f"ev_id BIGINT PRIMARY KEY DEFAULT snowflake.nextval('snowflake.id_seq'),{cols}", "citus": f"ev_id BIGSERIAL,{cols},PRIMARY KEY(payload,ev_id)", "cockroach": f"ev_id INT8 DEFAULT unique_rowid() PRIMARY KEY,{cols}"}.get(t, f"ev_id BIGSERIAL PRIMARY KEY,{cols}")
        pq(hs[0], pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}({pk});")
        if t == "citus":
            pq(hs[0], pt, u, pw, f"SELECT create_distributed_table('{tb}','payload');")
        elif t in ("pgedge", "pg17-async-streaming", "pg17-sync-streaming"):
            for n in hs[1:]:
                wcnt(n, pt, u, pw, f"information_schema.tables WHERE table_name='{tb}'", 1)
    m = 2 if t in MULTI_WRITER else 1
    c, j = (4, 2) if m == 2 else (8, 4)
    tps, avg, sdv, p95, ok, fl, rt = pb_run_v2(t, "H_append_only_insert", m, c, j, 12, "-f /tmp/s_append.sql -D nid=1", "-f /tmp/s_append.sql -D nid=2", hs, pt, u, pw, None)
    if t == "bucardo":
        sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_append", "5"], False)
    for _ in range(60):
        cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
        if len(set(cnts)) == 1 and cnts[0] >= ok:
            break
        time.sleep(1)
    cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
    dr = cnts[0] - ok
    cst = ("PASS_SINGLE_PRIMARY" if t.startswith("pg17-") else "PASS_CONVERGED") if (len(set(cnts)) == 1 and dr == 0) else "DIVERGED"
    return row(t, "H_append_only_insert", sc, 8, 12, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, dr, f"append_only {m}n rows={'/'.join(str(x) for x in cnts)}")


def _tc(pc, img, args, chk=True):
    tc_netem(pc, img, args, chk, sh_fn=sh)


def run_wan_netem(t, delay_ms, dur, hs, pt, u, pw, sc, netem, img, logf=None):
    """Inject tc netem delay on peers, run pgbench RW, and clean qdisc."""
    return _run_wan_netem(t, delay_ms, dur, hs, pt, u, pw, sc, netem, img, pb_run_v2, reset_ds_v2, logf=logf, tc_fn=_tc)


def append_summary_preserving(path: Path, topo: str, new_rows: list[dict]) -> None:
    """Append new topology rows atomically without altering existing rows."""
    header = ",".join(COLS)
    lines = path.read_text(encoding="utf-8").splitlines() if path.is_file() else []
    kept = [ln for ln in lines if ln and ln.split(",", 1)[0] != topo] if lines else [header]
    if not kept or kept[0] != header:
        kept.insert(0, header)
    buf = io.StringIO()
    csv.DictWriter(buf, fieldnames=COLS, lineterminator="\n").writerows(new_rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".csv.tmp")
    tmp.write_text("\n".join(kept) + "\n" + buf.getvalue(), encoding="utf-8", newline="\n")
    tmp.replace(path)


def upsert_modular_csv(path: Path, topo: str, new_rows: list[dict], topo_order: list[str], suite_order: list[str]) -> None:
    """Upsert rows for one topology preserving canonical order."""
    upsert_csv(path, topo, new_rows, topo_order, suite_order)
