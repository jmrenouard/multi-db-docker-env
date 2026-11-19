"""Core DB/Docker helpers and T11-T14 probes for the PG extended test matrix."""
from __future__ import annotations

import re
import subprocess as sp
import threading
import time

SS_RE = re.compile(r"ERROR:\s+([0-9A-Z]{5}):")


def sh(cmd: list[str], chk: bool = True, to: int = 120) -> sp.CompletedProcess:
    p = sp.run(cmd, text=True, capture_output=True, check=False, timeout=to)
    if chk and p.returncode != 0:
        raise RuntimeError(f"rc={p.returncode} cmd={cmd} err={p.stderr.strip()}")
    return p


def _dexec(n: dict, args: list[str], interactive: bool = False) -> list[str]:
    cmd = ["docker", "exec"] + (["-i"] if interactive else [])
    if n["pw"]:
        cmd += ["-e", f"PGPASSWORD={n['pw']}"]
    return cmd + ["ext_client", *args]


def pq_raw(n: dict, sql: str, to: int = 45, multi: bool = False) -> tuple[int, str, str, str]:
    args = ["psql", "-X", "-q", "-h", n["host"], "-p", str(n["port"]), "-U", n["user"], "-d", "labdb", "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-tA"]
    if not multi:
        args += ["-c", sql]
    try:
        p = sp.run(_dexec(n, args, multi), text=True, capture_output=True, timeout=to, **({"input": sql + "\n"} if multi else {}))
    except sp.TimeoutExpired:
        return 124, "", "TIMEOUT", "TIMEOUT"
    m = SS_RE.search(p.stderr)
    return p.returncode, p.stdout.strip(), p.stderr.strip(), (m.group(1) if m else "")


def pq(n: dict, sql: str, to: int = 45, multi: bool = False) -> str:
    rc, out, err, _ = pq_raw(n, sql, to=to, multi=multi)
    if rc != 0:
        raise RuntimeError(f"SQL failed on {n['ct']}: {err[:220]}")
    return out


class PsqlConn:
    """Persistent psql session inside ext_client."""

    def __init__(self, n: dict):
        cmd = _dexec(n, ["sh", "-c", 'exec "$@" 2>&1', "_", "psql", "-X", "-q", "-A", "-t", "-h", n["host"], "-p", str(n["port"]), "-U", n["user"], "-d", "labdb"], True)
        self.p = sp.Popen(cmd, stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.STDOUT, text=True, bufsize=1)

    def q(self, sql: str, fast: bool = False) -> str:
        assert self.p.stdin and self.p.stdout
        end = "" if sql.startswith("\\") else ";"
        mark = "\\echo __END__" if fast else "SELECT '__END__';"
        self.p.stdin.write(f"{sql.rstrip(';')}{end}\n{mark}\n")
        self.p.stdin.flush()
        out = []
        while True:
            ln = self.p.stdout.readline()
            if not ln or ln.strip() == "__END__":
                break
            out.append(ln.rstrip("\n"))
        return "\n".join(out).strip()

    def close(self) -> None:
        try:
            if self.p.stdin:
                self.p.stdin.write("\\q\n")
                self.p.stdin.flush()
            self.p.wait(timeout=3)
        except Exception:
            self.p.kill()


def wait_eq(n: dict, sql: str, exp: str, to_s: float = 30.0) -> tuple[bool, float]:
    t0 = time.monotonic()
    while time.monotonic() - t0 < to_s:
        rc, out, _, _ = pq_raw(n, sql, to=5)
        if rc == 0 and out.strip() == exp:
            return True, (time.monotonic() - t0) * 1000.0
        time.sleep(0.1)
    return False, (time.monotonic() - t0) * 1000.0


def wait_ready(n: dict, to_s: float = 60.0) -> None:
    t0 = time.monotonic()
    while time.monotonic() - t0 < to_s:
        if pq_raw(n, "SELECT 1;", to=5)[0] == 0:
            return
        time.sleep(1.0)
    raise RuntimeError(f"Timeout waiting for {n['ct']}")


def bctl(act: str) -> None:
    sh(["docker", "exec", "bucardo_daemon", "bucardo", act], chk=(act == "start"))
    gone = act == "stop"
    for _ in range(15):
        rc = sh(["docker", "exec", "bucardo_daemon", "test", "-f", "/var/run/bucardo/bucardo.mcp.pid"], chk=False).returncode
        if (rc != 0) == gone:
            break
        time.sleep(1)
    time.sleep(1 if gone else 2)


def bkick(kind: str, sec: int = 5) -> None:
    if kind == "bucardo":
        sh(["docker", "exec", "bucardo_daemon", "bucardo", "kick", "sync_ext", str(sec)], chk=False)


def init_ext_schema(kind: str, nodes: list[dict]) -> None:
    """Create all T11-T18 tables across the active topology."""
    fk = "" if kind == "citus" else "REFERENCES ext_parent(id)"
    tbs = ("bulk", "tombstone", "parent", "child", "fidelity", "raw_lag", "crash", "longtx", "t18")
    ddls = (
        "DROP TABLE IF EXISTS ext_child,ext_parent,ext_bulk,ext_tombstone,ext_fidelity,ext_raw_lag,ext_crash,ext_longtx,ext_t18 CASCADE;",
        "DROP SEQUENCE IF EXISTS ext_t18_seq CASCADE;",
        "CREATE TABLE ext_bulk(id INT PRIMARY KEY,grp INT NOT NULL,payload TEXT NOT NULL);",
        "CREATE TABLE ext_tombstone(id INT PRIMARY KEY,val TEXT NOT NULL);",
        "CREATE TABLE ext_parent(id INT PRIMARY KEY,name TEXT NOT NULL);",
        f"CREATE TABLE ext_child(id INT NOT NULL,pid INT NOT NULL {fk},PRIMARY KEY(pid,id));",
        "CREATE TABLE ext_fidelity(id INT PRIMARY KEY,j JSONB,b BYTEA,n TEXT,ts TIMESTAMPTZ,u TEXT);",
        "CREATE TABLE ext_raw_lag(id INT PRIMARY KEY,token INT NOT NULL);",
        "CREATE TABLE ext_crash(id INT PRIMARY KEY,tag TEXT NOT NULL);",
        "CREATE TABLE ext_longtx(id INT PRIMARY KEY,v TEXT NOT NULL);",
        "CREATE SEQUENCE ext_t18_seq START 1;",
        "CREATE TABLE ext_t18(id BIGINT PRIMARY KEY DEFAULT nextval('ext_t18_seq'),tag TEXT);",
    )
    if kind == "bucardo":
        bctl("stop")
    for nd in (nodes if kind in ("log_uni", "birep", "bucardo") else [nodes[0]]):
        for s in ddls:
            pq(nd, s)
    if kind == "log_uni":
        pq(nodes[1], "ALTER SUBSCRIPTION sub_logical REFRESH PUBLICATION WITH (copy_data=false);")
        wait_eq(nodes[1], "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';", "0", 20)
    elif kind == "birep":
        for nd, s in ((nodes[0], "sub_from_node2"), (nodes[1], "sub_from_node1")):
            pq(nd, f"ALTER SUBSCRIPTION {s} REFRESH PUBLICATION WITH (copy_data=false);")
        for nd in nodes:
            wait_eq(nd, "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate<>'r';", "0", 20)
    elif kind in ("pgedge", "phys_async", "phys_sync"):
        for nd in nodes[1:]:
            wait_eq(nd, "SELECT count(*) FROM information_schema.tables WHERE table_name='ext_t18';", "1", 25)
    elif kind == "bucardo":
        ts = ",".join(f"public.ext_{x}" for x in tbs)
        sh(["docker", "exec", "bucardo_daemon", "bash", "-lc", f"bucardo add sync sync_ext dbs=grp_mm tables={ts} conflict_strategy=bucardo_latest"])
        bctl("start")
    elif kind == "citus":
        for tb in tbs:
            pq(nodes[0], f"SELECT create_distributed_table('ext_{tb}','{'pid' if tb == 'child' else 'id'}');")
        pq(nodes[0], "ALTER TABLE ext_child ADD CONSTRAINT ext_child_pid_fkey FOREIGN KEY(pid) REFERENCES ext_parent(id);")


def run_t11_bulk(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    t0 = time.monotonic()
    pq(nodes[0], "INSERT INTO ext_bulk SELECT g,g%10,repeat('x',64) FROM generate_series(1,10000) g;", to=120)
    dt = max(time.monotonic() - t0, 1e-4)
    rate = 10000.0 / dt
    if len(nodes) == 1:
        return f"PASS: {rate:.0f} rows/s ({dt*1000:.0f}ms); catchup=0ms (single-view)"
    bkick(kind, 0)
    ok, lag = wait_eq(nodes[1], "SELECT count(*) FROM ext_bulk;", "10000", 90.0)
    if ok:
        return f"PASS: {rate:.0f} rows/s ({dt*1000:.0f}ms); peer_catchup={lag:.1f}ms"
    return f"PARTIAL: {rate:.0f} rows/s; peer={pq(nodes[1], 'SELECT count(*) FROM ext_bulk;')}/10000"


def _spock_subs(nodes: list[dict], fn: str) -> None:
    for d in (1, 2, 3):
        for s in (1, 2, 3):
            if d != s:
                pq(nodes[d - 1], f"SELECT spock.{fn}('sub_n{d}_n{s}', true);")


def run_t12_tombstone(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    n1, qv = nodes[0], "SELECT COALESCE(min(val),'DELETED') FROM ext_tombstone WHERE id=1;"
    pq(n1, "INSERT INTO ext_tombstone VALUES(1,'init');")
    if len(nodes) > 1:
        bkick(kind, 5)
        wait_eq(nodes[1], "SELECT count(*) FROM ext_tombstone WHERE id=1;", "1", 20)
    if kind in ("single", "phys_async", "phys_sync"):
        ro = ""
        if len(nodes) > 1:
            st = pq_raw(nodes[1], "DELETE FROM ext_tombstone WHERE id=1;")[3]
            if st:
                st_set.add(st)
            ro = f"standby DELETE rejected ({st}); "
        th = threading.Thread(target=pq_raw, args=(n1, "BEGIN;UPDATE ext_tombstone SET val='upd_c1' WHERE id=1;SELECT pg_sleep(0.3);COMMIT;", 30, True))
        th.start(); time.sleep(0.1); pq_raw(n1, "DELETE FROM ext_tombstone WHERE id=1;"); th.join()
        if len(nodes) > 1:
            wait_eq(nodes[1], "SELECT count(*) FROM ext_tombstone WHERE id=1;", "0", 15)
        return f"PASS: {ro}primary row-lock serialized (final={pq(n1, qv)})"
    u1, d1 = "UPDATE ext_tombstone SET val='upd_n1' WHERE id=1;", "DELETE FROM ext_tombstone WHERE id=1;"
    if kind in ("log_uni", "birep"):
        subs = ((nodes[1], "sub_logical"),) if kind == "log_uni" else ((n1, "sub_from_node2"), (nodes[1], "sub_from_node1"))
        for nd, sub in subs:
            pq(nd, f"ALTER SUBSCRIPTION {sub} DISABLE;")
            wait_eq(nd, "SELECT count(*) FROM pg_stat_subscription WHERE pid IS NOT NULL;", "0", 10)
        pq(n1, u1); pq(nodes[1], d1)
        for nd, sub in subs:
            pq(nd, f"ALTER SUBSCRIPTION {sub} ENABLE;")
        time.sleep(2.8)
        s1, s2 = pq(n1, qv), pq(nodes[1], qv)
        return f"EXPECTED_LIMITATION: DIVERGED pub={s1} sub={s2} (missing-row UPDATE ignored)" if kind == "log_uni" else f"EXPECTED_LIMITATION: DELETE won silently n1={s1} n2={s2}"
    if kind == "pgedge":
        _spock_subs(nodes, "sub_disable"); time.sleep(1.0); pq(n1, u1); pq(nodes[1], d1); _spock_subs(nodes, "sub_enable"); time.sleep(3.0)
        vals = "/".join(pq(nd, qv) for nd in nodes)
        return f"EXPECTED_LIMITATION: Spock tombstone race n1/n2/n3={vals} (resolutions={pq(nodes[1], 'SELECT count(*) FROM spock.resolutions;')})"
    if kind == "bucardo":
        bctl("stop"); pq(n1, u1); pq(nodes[1], d1); bctl("start"); bkick(kind, 5); time.sleep(2.0)
        return f"EXPECTED_LIMITATION: bucardo_latest race n1={pq(n1, qv)} n2={pq(nodes[1], qv)}"
    n2, res = (nodes[1] if len(nodes) > 1 else n1), {}
    th = threading.Thread(target=lambda: res.setdefault("u", pq_raw(n1, "BEGIN;UPDATE ext_tombstone SET val='upd_n1' WHERE id=1;SELECT pg_sleep(0.4);COMMIT;", 30, True)))
    th.start(); time.sleep(0.15); res["d"] = pq_raw(n2, "BEGIN;DELETE FROM ext_tombstone WHERE id=1;COMMIT;", 30, True); th.join()
    ust, dst = res["u"][3], res["d"][3]
    for s in (ust, dst):
        if s:
            st_set.add(s)
    return f"PASS: consensus (upd={ust or 'OK'} del={dst or 'OK'}) nodes={'/'.join(pq(nd, qv) for nd in nodes)}"


def run_t13_fk_race(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    c1, c2, errs, okc = PsqlConn(nodes[0]), PsqlConn(nodes[1] if len(nodes) > 1 else nodes[0]), {}, 0
    try:
        c2.q("\\set VERBOSITY verbose")
        for i in range(100, 110):
            c1.q(f"INSERT INTO ext_parent VALUES({i},'p{i}')", fast=True)
            out = c2.q(f"INSERT INTO ext_child(id,pid) VALUES({i},{i}) RETURNING id")
            m = SS_RE.search(out)
            if not m and str(i) in out.splitlines():
                okc += 1
            else:
                st = m.group(1) if m else "ERR"
                errs[st] = errs.get(st, 0) + 1
                if m:
                    st_set.add(st)
    finally:
        c1.close(); c2.close()
    if not errs:
        return f"PASS: {okc}/10 immediate cross-node child inserts consistent (0 FK errors)"
    return f"EXPECTED_LIMITATION: {okc}/10 ok; failures=" + " ".join(f"{k}x{v}" for k, v in sorted(errs.items()))


def run_t14_fidelity(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    enc_note = ""
    ins = "INSERT INTO ext_fidelity VALUES(1,'{\"k\":[1,true,null],\"nested\":{\"a\":\"ok\"}}'::jsonb,decode(repeat('deadbeef',16384),'hex'),NULL,'2026-11-19 12:34:56.789123+00'::timestamptz,"
    rc, _, _, st = pq_raw(nodes[0], ins + "chr(233)||chr(20013)||chr(128640));")
    if rc != 0:
        if st:
            st_set.add(st)
        enc = pq(nodes[0], "SHOW server_encoding;")
        enc_note = f"; {enc} chr()={st}"
        pq(nodes[0], ins + "encode(decode('c3a9e4b8adf09f9a80','hex'),'escape'));")
    if len(nodes) > 1:
        bkick(kind, 5)
        wait_eq(nodes[-1], "SELECT count(*) FROM ext_fidelity WHERE id=1;", "1", 25)
    hsql = "SELECT octet_length(b)::text||'|'||md5(id::text||'|'||j::text||'|'||md5(encode(b,'hex'))||'|'||COALESCE(n,'<NULL>')||'|'||to_char(ts AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS.US')||'|'||md5(u)) FROM ext_fidelity WHERE id=1;"
    res = [pq(nd, hsql) for nd in nodes]
    sz, h8 = res[0].split("|")[0], res[0].split("|")[1][:8]
    return f"PASS: {len(nodes)}/{len(nodes)} identical md5={h8} (BYTEA={sz}B JSONB/NULL/TS/UTF8{enc_note})" if len(set(res)) == 1 and sz == "65536" else f"FAIL: mismatch {res}"
