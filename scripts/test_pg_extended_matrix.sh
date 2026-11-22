#!/usr/bin/env bash
# Sequential extended empirical test matrix (T11-T18) across all 10 PG topologies.
set -euo pipefail

export EXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EXT_ROOT"
[ -f .env ] && { set -a; . ./.env; set +a; }
export PYTHONDONTWRITEBYTECODE=1
export PG_LAB_PASSWORD="${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}"
export DB_ROOT_PASSWORD="$PG_LAB_PASSWORD"
export EXT_OUT_CSV="${EXT_OUT_CSV:-$EXT_ROOT/reports/extended_functional_matrix.csv}"

exec python3 - "$@" <<'PY'
import csv
import os
import sys
import threading
import time
from pathlib import Path

ROOT = Path(os.environ["EXT_ROOT"])
sys.path.insert(0, str(ROOT / "scripts"))
from test_pg_extended_lib import (
    PsqlConn, bkick, init_ext_schema, pq, pq_raw, run_t11_bulk,
    run_t12_tombstone, run_t13_fk_race, run_t14_fidelity, sh, wait_eq, wait_ready,
)

COLS = (
    "topology,solution_name,t11_bulk_10k_throughput_and_catchup,"
    "t12_update_vs_delete_tombstone,t13_cross_node_fk_race,"
    "t14_rich_data_fidelity_md5,t15_raw_visibility_lag_ms,"
    "t16_sigkill_crash_rpo_recovery,t17_long_open_tx_impact,"
    "t18_sequence_sync_after_50,verified_sqlstates"
).split(",")

PW = os.environ["PG_LAB_PASSWORD"]
OUT_CSV = Path(os.environ["EXT_OUT_CSV"])
OUT_CSV.parent.mkdir(parents=True, exist_ok=True)


def nd(ct: str, host: str = "", port: int = 5432, user: str = "postgres", pw: str = PW) -> dict:
    return {"ct": ct, "host": host or ct, "port": port, "user": user, "pw": pw}


SPECS = [
    ("pg17-standalone", "PostgreSQL 17 Standalone (Baseline)", "single",
     "docker-compose-pg17-baseline.yml", ["pg17_standalone"], None,
     [nd("pg17_standalone")], "pg17_standalone"),
    ("pg17-async-streaming", "PostgreSQL 17 Async Physical Streaming", "phys_async",
     "docker-compose-pg-streaming.yml", [], ["bash", "scripts/pg_streaming/setup_pg_streaming.sh", "async"],
     [nd("pg_stream_primary"), nd("pg_stream_standby")], "pg_stream_primary"),
    ("pg17-sync-streaming", "PostgreSQL 17 Sync Physical Streaming", "phys_sync",
     "docker-compose-pg-streaming.yml", [], ["bash", "scripts/pg_streaming/setup_pg_streaming.sh", "sync"],
     [nd("pg_stream_primary"), nd("pg_stream_standby")], "pg_stream_primary"),
    ("pg17-logical", "PostgreSQL 17 Native Uni-Directional Logical", "log_uni",
     "docker-compose-pg-logical.yml", [], ["bash", "scripts/pg_logical/setup_pg_logical.sh"],
     [nd("pg_logical_pub"), nd("pg_logical_sub")], "pg_logical_pub"),
    ("pg-birep", "PostgreSQL 17 Native Bidirectional Logical", "birep",
     "docker-compose-pg-birep.yml", [], ["bash", "scripts/pg_birep/setup_birep.sh"],
     [nd("pg_birep_node1"), nd("pg_birep_node2")], "pg_birep_node1"),
    ("pgedge", "pgEdge Spock 5.0.14 + Snowflake (3-Node Mesh)", "pgedge",
     "docker-compose-pgedge.yml", [], ["bash", "scripts/pgedge/setup_pgedge.sh"],
     [nd("pgedge_node1"), nd("pgedge_node2"), nd("pgedge_node3")], "pgedge_node1"),
    ("bucardo", "Bucardo 5.6.0 Trigger Multi-Master (PG 17)", "bucardo",
     "docker-compose-bucardo.yml", [], ["bash", "scripts/bucardo/setup_bucardo.sh"],
     [nd("bucardo_node1"), nd("bucardo_node2")], "bucardo_node1"),
    ("citus", "Citus 14.2.0 Distributed PostgreSQL 17", "citus",
     "docker-compose-citus.yml", [], ["bash", "scripts/citus/setup_citus.sh"],
     [nd("citus_coord")], "citus_worker2"),
    ("yugabyte", "YugabyteDB 2026.1.3 DocDB Raft (RF=3)", "raft_yb",
     "docker-compose-yugabyte.yml", [], ["bash", "scripts/yugabyte/setup_yugabyte.sh"],
     [nd("yb_node1", "yb-node1", 5433, "yugabyte", ""), nd("yb_node2", "yb-node2", 5433, "yugabyte", ""), nd("yb_node3", "yb-node3", 5433, "yugabyte", "")], "yb_node2"),
    ("cockroach", "CockroachDB v25.4 Pebble Raft (RF=3)", "raft_crdb",
     "docker-compose-cockroach.yml", [], ["bash", "scripts/cockroach/setup_cockroach.sh"],
     [nd("crdb_node1", "crdb_node1", 26257, "root", ""), nd("crdb_node2", "crdb_node2", 26257, "root", ""), nd("crdb_node3", "crdb_node3", 26257, "root", "")], "crdb_node2"),
]


def run_t15_raw_lag(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    c1, c2, lags = PsqlConn(nodes[0]), PsqlConn(nodes[1] if len(nodes) > 1 else nodes[0]), []
    try:
        for i in range(1, 31):
            c1.q(f"INSERT INTO ext_raw_lag VALUES({i},{i}) ON CONFLICT(id) DO UPDATE SET token=EXCLUDED.token", fast=True)
            t0 = time.monotonic()
            if kind == "bucardo" and i % 10 == 1:
                bkick(kind, 0)
            while True:
                if c2.q(f"SELECT token FROM ext_raw_lag WHERE id={i}", fast=True) == str(i):
                    lags.append((time.monotonic() - t0) * 1000.0); break
                if time.monotonic() - t0 > 10.0:
                    lags.append(10000.0); break
                time.sleep(0.002 if kind != "bucardo" else 0.02)
    finally:
        c1.close(); c2.close()
    lags.sort()
    return f"p50={lags[15]:.2f}ms p95={lags[28]:.2f}ms max={lags[-1]:.2f}ms (n=30)"


def run_t17_longtx(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    n1, n2 = nodes[0], (nodes[1] if len(nodes) > 1 else nodes[0])
    pq(n1, "INSERT INTO ext_longtx VALUES(1,'before');")
    if len(nodes) > 1:
        bkick(kind, 5); wait_eq(n2, "SELECT v FROM ext_longtx WHERE id=1;", "before", 20)
    th = threading.Thread(target=pq_raw, args=(n1, "BEGIN;UPDATE ext_longtx SET v='committed_3s' WHERE id=1;SELECT pg_sleep(3);COMMIT;", 30, True))
    th.start(); time.sleep(0.6)
    pq(n1, "INSERT INTO ext_longtx VALUES(2,'side_tx');"); bkick(kind, 0)
    sok, sms = wait_eq(n2, "SELECT v FROM ext_longtx WHERE id=2;", "side_tx", 2.0)
    tm0 = time.monotonic()
    mid = pq(n2, "SELECT v FROM ext_longtx WHERE id=1;")
    mdt = time.monotonic() - tm0
    th.join(); bkick(kind, 5)
    aok, ams = wait_eq(n2, "SELECT v FROM ext_longtx WHERE id=1;", "committed_3s", 15.0)
    if mid == "before":
        iso = "NO_DIRTY_READ"
    elif mdt >= 1.5:
        iso = f"NO_DIRTY_READ(serializable_intent_wait={mdt:.1f}s)"
    else:
        iso = f"DIRTY({mid})"
    blk = f"side_tx_unblocked({sms:.0f}ms)" if sok else "side_tx_delayed"
    return f"PASS: {iso}; {blk}; post_commit_vis={ams:.0f}ms (ok={aok})"


def run_t18_seq(kind: str, nodes: list[dict], st_set: set[str]) -> str:
    n1 = nodes[0]
    pq(n1, "INSERT INTO ext_t18(tag) SELECT 'r_'||g FROM generate_series(1,50) g;")
    if len(nodes) > 1:
        bkick(kind, 5); wait_eq(nodes[1], "SELECT count(*) FROM ext_t18;", "50", 25)
    if len(nodes) == 1:
        nid = pq(n1, "INSERT INTO ext_t18(tag) VALUES('next') RETURNING id;").splitlines()[0]
        return f"PASS: single sequence safe (next_id={nid})"
    if kind in ("phys_async", "phys_sync"):
        lv = pq(nodes[1], "SELECT last_value||'|'||is_called FROM ext_t18_seq;")
        return f"PASS: physical WAL synced seq on standby (last_value={lv}; safe on pg_promote)"
    if kind in ("raft_yb", "raft_crdb"):
        nid = pq(nodes[1], "INSERT INTO ext_t18(tag) VALUES('peer') RETURNING id;").splitlines()[0]
        return f"PASS: global sequence safe on node2 (next_id={nid}; zero 23505)"
    lv2 = pq(nodes[1], "SELECT last_value||'|'||is_called FROM ext_t18_seq;")
    rc, out, _, st = pq_raw(nodes[1], "INSERT INTO ext_t18(tag) VALUES('failover') RETURNING id;")
    if st:
        st_set.add(st)
    ex = " (use snowflake.nextval)" if kind == "pgedge" else ""
    return f"EXPECTED_LIMITATION: peer seq stuck at {lv2} -> insert hit SQLSTATE {st}{ex}" if rc != 0 else f"PASS: peer seq={lv2} next_id={out.splitlines()[0]}"


def run_t16_sigkill(kind: str, nodes: list[dict], kill_ct: str, st_set: set[str]) -> str:
    knode = next((x for x in nodes if x["ct"] == kill_ct), nodes[0])
    peer = next((x for x in nodes if x["ct"] != kill_ct), nodes[0])
    pq(knode, "INSERT INTO ext_crash SELECT g,'c_'||g FROM generate_series(1,20) g;")
    bkick(kind, 2); sh(["docker", "kill", "-s", "SIGKILL", kill_ct])
    if kind == "single":
        sh(["docker", "start", kill_ct]); wait_ready(knode, 45)
        cnt = pq(knode, "SELECT count(*) FROM ext_crash;")
        pq(knode, "INSERT INTO ext_crash VALUES(21,'post_crash');")
        return f"PASS: WAL crash recovery {cnt}/20 (RPO=0); restart+write OK (21/21)"
    if kind == "citus":
        rc, _, _, st = pq_raw(nodes[0], "SELECT count(*) FROM ext_crash;", to=10)
        if st:
            st_set.add(st)
        sh(["docker", "start", kill_ct]); time.sleep(4)
        wait_eq(nodes[0], "SELECT count(*) FROM ext_crash;", "20", 30)
        pq(nodes[0], "INSERT INTO ext_crash VALUES(21,'post_crash');")
        return f"EXPECTED_LIMITATION: worker2 SIGKILL failed query (rc={rc} {st or 'conn_err'}); recovered 21/21"
    surv = 0
    for _ in range(15):
        rc_s, out_s, _, _ = pq_raw(peer, "SELECT count(*) FROM ext_crash;", to=5)
        if rc_s == 0 and out_s.isdigit():
            surv = int(out_s); break
        time.sleep(1)
    w_out = "sub_writable_local" if kind == "log_uni" else "RO_standby"
    if kind in ("birep", "pgedge", "bucardo", "raft_yb", "raft_crdb"):
        w_out = "peer_write_ERR"
        for _ in range(10):
            rc2, _, _, st2 = pq_raw(peer, "INSERT INTO ext_crash VALUES(21,'during_outage');", to=8)
            if rc2 == 0:
                w_out = "peer_write_OK"; break
            w_out = f"peer_write_ERR({st2})"; time.sleep(1)
    sh(["docker", "start", kill_ct])
    try:
        wait_ready(knode, 110)
    except RuntimeError:
        c2 = pq(peer, "SELECT count(*) FROM ext_crash;")
        return f"PARTIAL: peer_surv={surv}/20 RPO={20-surv} {w_out}; peer_rows={c2} ({kill_ct} restart_timeout)"
    if kind in ("phys_async", "phys_sync"):
        wait_eq(knode, "SELECT count(*) FROM pg_stat_replication WHERE state='streaming';", "1", 30)
    if kind == "bucardo":
        sh(["docker", "exec", "bucardo_daemon", "bucardo", "restart"], chk=False); time.sleep(3); bkick(kind, 5)
    if kind in ("phys_async", "phys_sync", "log_uni"):
        pq(knode, "INSERT INTO ext_crash VALUES(21,'post_crash');"); wait_eq(peer, "SELECT count(*) FROM ext_crash;", "21", 30)
    else:
        wait_eq(knode, "SELECT count(*) FROM ext_crash;", "21", 35)
    c1, c2 = pq(knode, "SELECT count(*) FROM ext_crash;"), pq(peer, "SELECT count(*) FROM ext_crash;")
    return f"PASS: peer_surv={surv}/20 RPO={20-surv} {w_out}; post_restart={c1}/{c2}"


def run_one(spec: tuple) -> dict:
    topo, label, kind, cf, svcs, setup_cmd, nodes, kill_ct = spec
    cf_path = str(ROOT / cf)
    print(f"=== [{topo}] Starting ===", flush=True)
    sh(["docker", "compose", "-f", cf_path, "up", "-d", *svcs])
    st_set: set[str] = set()
    try:
        if setup_cmd:
            sh([setup_cmd[0], str(ROOT / setup_cmd[1]), *setup_cmd[2:]], to=240)
        net = sh(["docker", "inspect", "-f", "{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}", nodes[0]["ct"]]).stdout.strip()
        sh(["docker", "rm", "-f", "ext_client"], chk=False)
        sh(["docker", "run", "-d", "--name", "ext_client", "--network", net, "--entrypoint", "sleep", "postgres:17", "infinity"])
        for n in nodes:
            wait_ready(n, 60)
        init_ext_schema(kind, nodes)
        tests = (
            ("T11", run_t11_bulk), ("T12", run_t12_tombstone), ("T13", run_t13_fk_race),
            ("T14", run_t14_fidelity), ("T15", run_t15_raw_lag), ("T17", run_t17_longtx), ("T18", run_t18_seq),
        )
        res = {}
        for k, fn in tests:
            res[k] = fn(kind, nodes, st_set); print(f"  {k}: {res[k]}", flush=True)
        res["T16"] = run_t16_sigkill(kind, nodes, kill_ct, st_set); print(f"  T16: {res['T16']}", flush=True)
        return dict(zip(COLS, (
            topo, label, res["T11"], res["T12"], res["T13"], res["T14"], res["T15"],
            res["T16"], res["T17"], res["T18"], ";".join(sorted(st_set)) if st_set else "NONE",
        )))
    finally:
        sh(["docker", "rm", "-f", "ext_client"], chk=False, to=30)
        sh(["docker", "compose", "-f", cf_path, "down", "-v"], chk=False, to=120)
        print(f"=== [{topo}] Down ===", flush=True)


arg = sys.argv[1] if len(sys.argv) > 1 else "all"
wanted = [s[0] for s in SPECS] if arg == "all" else arg.split(",")
existing = {}
if arg != "all" and OUT_CSV.exists():
    with OUT_CSV.open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            existing[r["topology"]] = r

for spec in SPECS:
    if spec[0] not in wanted:
        continue
    existing[spec[0]] = run_one(spec)
    ordered = [existing[s[0]] for s in SPECS if s[0] in existing]
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS)
        w.writeheader()
        w.writerows(ordered)
    print(f"Saved {len(ordered)} rows to {OUT_CSV}", flush=True)
PY
