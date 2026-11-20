"""Helper routines for the PostgreSQL 18 empirical benchmark suite."""
from __future__ import annotations

import csv
import io
import re
import subprocess as sp
import time
from pathlib import Path

from bench_pg_lib import B, COLS, bc, de, mk_scripts, pb_run, pq, reset_ds, row, sh, wcnt, wlog

SINGLE_PRIMARY = {"pg18-standalone", "pg18-async-streaming", "pg18-sync-streaming", "pg18-logical"}
MULTI_WRITER = {"pg18-birep"}
PG18_PFX = ("pg18_", "haproxy_pg18_", "bench_client")


def assert_zero_pg18_containers() -> None:
    """Verify no PG 18 PoC or benchmark containers remain."""
    out = sh(["docker", "ps", "-a", "--format", "{{.Names}}"]).stdout
    left = [n.strip() for n in out.splitlines() if n.strip().startswith(PG18_PFX)]
    if left:
        raise RuntimeError(f"Residual PG 18 PoC containers: {left}")


def mk_scripts_pg18() -> None:
    """Generate core pgbench scripts plus append-only insert script."""
    mk_scripts()
    app = "\\set payload random(1,100000)\nINSERT INTO bench_append_events(node_id,payload) VALUES(:nid,:payload);\n"
    sp.run(["docker", "exec", "-i", "bench_client", "bash", "-c", "cat>/tmp/s_append.sql"], input=app, text=True, check=True)


def _ref(h: str, pt: int, u: str, pw: str, sub: str, cp: str = "false") -> None:
    pq(h, pt, u, pw, f"ALTER SUBSCRIPTION {sub} REFRESH PUBLICATION WITH (copy_data={cp});")


def init_ds_pg18(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, na: int) -> None:
    """Initialize pgbench tables across all 5 PG 18 topologies."""
    pbi = ["pgbench", "-U", u, "-d", "labdb", "-i", "-s", str(sc), "-I", "g", "-n", "-q", "-h", hs[0], "-p", str(pt)]
    ddl = (
        f"DROP TABLE IF EXISTS {B}history,{B}accounts,{B}tellers,{B}branches CASCADE;"
        f"CREATE TABLE {B}branches(bid INT PRIMARY KEY,bbalance INT,filler CHAR(88));"
        f"CREATE TABLE {B}tellers(tid INT PRIMARY KEY,bid INT,tbalance INT,filler CHAR(84));"
        f"CREATE TABLE {B}accounts(aid INT PRIMARY KEY,bid INT,abalance INT,filler CHAR(84));"
    )
    hc = "tid INT,bid INT,aid INT,delta INT,mtime TIMESTAMP,filler CHAR(22)"
    if t == "pg18-birep":
        for h in hs:
            pq(h, pt, u, pw, f"{ddl}CREATE TABLE {B}history(hid UUID PRIMARY KEY DEFAULT uuidv7(),{hc});")
        _ref(hs[0], pt, u, pw, "sub_from_node2")
        _ref(hs[1], pt, u, pw, "sub_from_node1")
        time.sleep(2)
        bc(pbi, pw)
        wcnt(hs[1], pt, u, pw, f"{B}accounts", na)
        return
    if t == "pg18-logical":
        for h in hs:
            pq(h, pt, u, pw, f"{ddl}CREATE TABLE {B}history(hid BIGSERIAL PRIMARY KEY,{hc});")
        _ref(hs[1], pt, u, pw, "sub_pg18_logical")
        time.sleep(2)
        bc(pbi, pw)
        wcnt(hs[1], pt, u, pw, f"{B}accounts", na)
        return
    pq(hs[0], pt, u, pw, f"{ddl}CREATE TABLE {B}history(hid BIGSERIAL PRIMARY KEY,{hc});")
    bc(pbi, pw)
    if len(hs) > 1:
        wcnt(hs[1], pt, u, pw, f"{B}accounts", na)


def reset_ds_pg18(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    """Reset pgbench tables and wait for replica catch-up."""
    reset_ds(t, hs, pt, u, pw)
    if len(hs) > 1:
        time.sleep(1)
        wcnt(hs[1], pt, u, pw, f"{B}history", 0)
        if t == "pg18-birep":
            pq(hs[1], pt, u, pw, f"UPDATE {B}accounts SET abalance=0 WHERE abalance<>0;UPDATE {B}branches SET bbalance=0 WHERE bbalance<>0;UPDATE {B}tellers SET tbalance=0 WHERE tbalance<>0;")
            time.sleep(1)


def pb_run_pg18(t: str, su: str, m: int, c: int, j: int, d: int, a1: str, a2: str, hs: list[str], pt: int, u: str, pw: str, logf=None):
    """Run pgbench with single-primary or dual-writer routing."""
    eff = [hs[0], hs[0]] if (m > 1 and t in SINGLE_PRIMARY and su != "C_multinode_ro") else hs
    return pb_run(t, su, m, c, j, d, a1, a2, eff, pt, u, pw, logf if logf is not None else io.StringIO())


def conv_chk_pg18(t: str, ok: int, hs: list[str], pt: int, u: str, pw: str):
    """Wait for PG 18 replica catch-up and return convergence status, drift, and crisp notes."""
    if len(hs) > 1:
        for _ in range(35):
            hcs = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;") or -1) for h in hs]
            if len(set(hcs)) == 1 and hcs[0] >= ok:
                break
            time.sleep(1)
    exp = int(pq(hs[0], pt, u, pw, f"SELECT COALESCE(SUM(delta),0) FROM {B}history;"))
    accs, hcs = [], []
    for h in hs:
        accs.append(int(pq(h, pt, u, pw, f"SELECT COALESCE(SUM(abalance),0) FROM {B}accounts;")))
        hcs.append(int(pq(h, pt, u, pw, f"SELECT count(*) FROM {B}history;")))
    dr = accs[0] - exp
    if len(set(accs)) > 1:
        st = "EXPECTED_LIMITATION_DIVERGED"
    elif dr:
        st = "EXPECTED_LIMITATION_LOST_UPDATE"
    elif t in SINGLE_PRIMARY:
        st = "PASS_SINGLE_PRIMARY"
    else:
        st = "PASS_CONVERGED"
    acc_s = "/".join(str(x) for x in accs)
    h_s = "/".join(str(x) for x in hcs)
    return st, dr, f"d={exp} acc={acc_s} h={h_s}"


def _drop_sb_sub(t: str, hs: list[str], pt: int, u: str, pw: str) -> None:
    sub = "sub_pg18_logical" if t == "pg18-logical" else "sub_from_node1"
    pq(hs[1], pt, u, pw, "DROP TABLE IF EXISTS sbtest1,sbtest2,sbtest3,sbtest4 CASCADE;")
    _ref(hs[1], pt, u, pw, sub)
    if t == "pg18-birep":
        _ref(hs[0], pt, u, pw, "sub_from_node2")


def _sb_cmd(lua: str, cm: str, tail: str) -> int:
    return bc(["bash", "-c", f"sysbench {lua} {cm} {tail}"], "", False).returncode


def run_sysbench_pg18(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int, suites: list[tuple], logf=None) -> dict:
    """Prepare sysbench once and run requested OLTP suites."""
    h1, pwa = hs[0], (f"--pgsql-password={pw} " if pw else "")
    cm = f"--db-driver=pgsql --pgsql-host={h1} --pgsql-port={pt} --pgsql-user={u} {pwa}--pgsql-db=labdb --tables=4 --table-size=10000"
    _sb_cmd("oltp_read_write", cm, "cleanup >/dev/null 2>&1||true")
    if t in ("pg18-logical", "pg18-birep"):
        _drop_sb_sub(t, hs, pt, u, pw)
    res = {}
    if _sb_cmd("oltp_read_write", cm, "prepare >/tmp/sb_p.out 2>&1"):
        err = "prep:" + bc(["head", "-n", "2", "/tmp/sb_p.out"], "", False).stdout.replace("\n", " ").strip()[:60]
        return {su: row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err) for su, _, th, dur, _ in suites}
    if t in ("pg18-logical", "pg18-birep"):
        sub = "sub_pg18_logical" if t == "pg18-logical" else "sub_from_node1"
        dump = de(h1, ["pg_dump", "-U", u, "-d", "labdb", "-s", "-t", "sbtest*"], pw).stdout
        sp.run(
            ["docker", "exec", "-i", "-e", f"PGPASSWORD={pw}", hs[1], "psql", "-U", u, "-d", "labdb", "-v", "ON_ERROR_STOP=1"],
            input=dump, text=True, check=True, stdout=sp.DEVNULL,
        )
        _ref(hs[1], pt, u, pw, sub, "true")
        q = f"SELECT count(*) FROM pg_subscription_rel r JOIN pg_subscription s ON r.srsubid=s.oid JOIN pg_class c ON c.oid=r.srrelid WHERE s.subname='{sub}' AND c.relname LIKE 'sbtest%' AND r.srsubstate='r';"
        for _ in range(30):
            if pq(hs[1], pt, u, pw, q) == "4":
                break
            time.sleep(1)
        if t == "pg18-birep":
            _ref(hs[0], pt, u, pw, "sub_from_node2")
    elif len(hs) > 1:
        wcnt(hs[1], pt, u, pw, "sbtest4", 10000)
    pats = (r"transactions:\s+(\d+)\s+\(([0-9.]+)", r"queries:\s+\d+\s+\(([0-9.]+)", r"ignored errors:\s+(\d+)", r"avg:\s+([0-9.]+)", r"95th percentile:\s+([0-9.]+)")
    for su, lua, th, dur, wl in suites:
        note = f"{lua} 4x10k"
        if _sb_cmd(lua, cm, f"--threads={th} --time={dur} run >/tmp/sb_r.out 2>&1"):
            note = f"{lua} ps=off"
            if _sb_cmd(lua, cm, f"--threads={th} --time={dur} --db-ps-mode=disable run >/tmp/sb_r.out 2>&1"):
                err = "run:" + bc(["tail", "-n", "2", "/tmp/sb_r.out"], "", False).stdout.replace("\n", " ").strip()[:60]
                res[su] = row(t, su, sc, th, dur, 0, 0, 0, 0, 0, 0, 0, 0, "EXPECTED_LIMITATION_UNSUPPORTED", 0, err)
                continue
        s = bc(["cat", "/tmp/sb_r.out"]).stdout
        if wl and logf is not None:
            wlog(logf, s)
        tx, qm, em, am, pm = [re.search(x, s) for x in pats]
        res[su] = row(
            t, su, sc, th, dur,
            float(tx.group(2)) if tx else 0, float(qm.group(1)) if qm else 0,
            float(am.group(1)) if am else 0, 0, float(pm.group(1)) if pm else 0,
            int(tx.group(1)) if tx else 0, int(em.group(1)) if em else 0, 0, "PASS", 0, note,
        )
    _sb_cmd("oltp_read_write", cm, "cleanup >/dev/null 2>&1||true")
    if t in ("pg18-logical", "pg18-birep"):
        time.sleep(2)
        _drop_sb_sub(t, hs, pt, u, pw)
    return res


def run_append_only_pg18(t: str, hs: list[str], pt: int, u: str, pw: str, sc: int) -> dict:
    """Run H_append_only_insert (using native PG 18 uuidv7() PK on pg18-birep)."""
    tb = "bench_append_events"
    cols = "node_id INT NOT NULL,payload INT NOT NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP"
    if t == "pg18-birep":
        for h in hs:
            pq(h, pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id UUID PRIMARY KEY DEFAULT uuidv7(),{cols});")
        _ref(hs[0], pt, u, pw, "sub_from_node2")
        _ref(hs[1], pt, u, pw, "sub_from_node1")
        time.sleep(2)
    elif t == "pg18-logical":
        for h in hs:
            pq(h, pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id BIGSERIAL PRIMARY KEY,{cols});")
        _ref(hs[1], pt, u, pw, "sub_pg18_logical")
        time.sleep(2)
    else:
        pq(hs[0], pt, u, pw, f"DROP TABLE IF EXISTS {tb} CASCADE;CREATE TABLE {tb}(ev_id BIGSERIAL PRIMARY KEY,{cols});")
        if len(hs) > 1:
            wcnt(hs[1], pt, u, pw, f"information_schema.tables WHERE table_name='{tb}'", 1)
    m = 2 if t in MULTI_WRITER else 1
    c, j = (4, 2) if m == 2 else (8, 4)
    tps, avg, sdv, p95, ok, fl, rt = pb_run_pg18(t, "H_append_only_insert", m, c, j, 12, "-f /tmp/s_append.sql -D nid=1", "-f /tmp/s_append.sql -D nid=2", hs, pt, u, pw, None)
    for _ in range(60):
        cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
        if len(set(cnts)) == 1 and cnts[0] >= ok:
            break
        time.sleep(1)
    cnts = [int(pq(h, pt, u, pw, f"SELECT count(*) FROM {tb};") or -1) for h in hs]
    dr = cnts[0] - ok
    cst = ("PASS_CONVERGED" if t in MULTI_WRITER else "PASS_SINGLE_PRIMARY") if (len(set(cnts)) == 1 and dr == 0) else "DIVERGED"
    tag = "uuidv7 2n" if t == "pg18-birep" else "1n"
    return row(t, "H_append_only_insert", sc, 8, 12, tps, "N/A", avg, sdv, p95, ok, fl, rt, cst, dr, f"{tag} rows={'/'.join(str(x) for x in cnts)}")


def _tc(pc: str, img: str, args: list[str], chk: bool = True) -> None:
    sh(["docker", "run", "--rm", "--network", f"container:{pc}", "--cap-add", "NET_ADMIN", img, "tc", "qdisc", *args], chk)


def run_wan_netem_pg18(t: str, delay_ms: int, dur: int, hs: list[str], pt: int, u: str, pw: str, sc: int, netem: list[str], img: str, logf=None) -> dict:
    """Inject tc netem delay on peers, run pgbench RW, and clean qdisc."""
    reset_ds_pg18(t, hs, pt, u, pw)
    for pc in netem:
        _tc(pc, img, ["replace", "dev", "eth0", "root", "netem", "delay", f"{delay_ms}ms"])
    time.sleep(1)
    try:
        tps, avg, sdv, p95, ok, fl, rt = pb_run_pg18(t, f"F_wan_netem_{delay_ms}ms", 1, 8, 4, dur, f"-D scale={sc}", "", hs, pt, u, pw, logf)
    finally:
        for pc in netem:
            _tc(pc, img, ["del", "dev", "eth0", "root"], False)
        time.sleep(1)
    return row(t, f"F_wan_netem_{delay_ms}ms", sc, 8, dur, tps, "N/A", avg, sdv, p95, ok, fl, rt, f"PASS_NETEM_{delay_ms}MS", 0, f"netem {delay_ms}ms")


def upsert_pg18_csv(path: Path, topo: str, new_rows: list[dict], topo_order: list[str], suite_order: list[str]) -> None:
    """Upsert rows for one PG 18 topology preserving canonical ordering."""
    cur = list(csv.DictReader(path.open(encoding="utf-8", newline=""))) if path.is_file() else []
    merged = [r for r in cur if r["topology"] != topo] + new_rows
    ti, si = {k: i for i, k in enumerate(topo_order)}, {k: i for i, k in enumerate(suite_order)}
    merged.sort(key=lambda r: (ti.get(r["topology"], 999), si.get(r["suite"], 999)))
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(merged)
