"""Deterministic unit tests for PG benchmark and extended test libraries."""
import csv
import gc
import io
import os
import re
import shutil
import subprocess as sp
import sys
import tempfile
import unittest
import warnings
from pathlib import Path
from unittest.mock import patch

SCRIPTS_DIR = str(Path(__file__).resolve().parent.parent / "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import bench_pg18_lib as b18
import bench_pg_lib as b1
import bench_pg_opt_common as boc
import bench_pg_opt_workloads as bow
import bench_pg_optimized_lib as bopt
import bench_pg_v2_lib as b2
import test_pg_extended_lib as ext


class TestBenchPgLib(unittest.TestCase):
    def test_row_and_sh(self):
        vals = list(range(len(b1.COLS)))
        r = b1.row(*vals)
        self.assertEqual(len(r), len(b1.COLS))
        self.assertEqual(r["topology"], 0)
        self.assertEqual(r["notes"], len(b1.COLS) - 1)

        ok_cp = sp.CompletedProcess(["echo"], 0, stdout="hi", stderr="")
        fail_cp = sp.CompletedProcess(["false"], 1, stdout="", stderr="boom")
        with patch("bench_pg_lib.sp.run", return_value=ok_cp):
            self.assertEqual(b1.sh(["echo"]).stdout, "hi")
        with patch("bench_pg_lib.sp.run", return_value=fail_cp):
            self.assertEqual(b1.sh(["false"], chk=False).returncode, 1)
            with self.assertRaises(RuntimeError):
                b1.sh(["false"], chk=True)

    def test_wlog_deduplicates_notice_and_strips_latencies(self):
        raw = "\n".join([
            "NOTICE:  No license is installed",
            "NOTICE:  No license is installed",
            "NOTICE:  No license is installed",
            "NOTICE:  No license is installed",
            "statement latencies in milliseconds:",
            "   0.123  10  0  SELECT 1;",
            "tps = 420.50",
        ])
        buf = io.StringIO()
        b1.wlog(buf, raw)
        out = buf.getvalue()
        self.assertEqual(out.count("NOTICE:  No license is installed"), 2)
        self.assertIn("[... repeated NOTICE lines omitted ...]", out)
        self.assertNotIn("statement latencies", out)
        self.assertNotIn("SELECT 1;", out)
        self.assertIn("tps = 420.50", out)

    def test_conv_chk_states(self):
        # Converged multi-node (exp=100, both nodes acc=100)
        with patch.object(b1, "pq", side_effect=["100", "100", "100", "5", "100", "100", "5"]):
            st, dr, note = b1.conv_chk("citus", 5, ["n1", "n2"], 5432, "u", "p")
        self.assertEqual((st, dr), ("PASS_CONVERGED", 0))
        self.assertIn("exp_delta=100", note)

        # Single-primary convergence label
        with patch.object(b1, "time"), patch.object(b1, "pq", side_effect=["50", "50", "50", "3"]):
            st, dr, _ = b1.conv_chk("pg17-sync-streaming", 3, ["n1"], 5432, "u", "p")
        self.assertEqual((st, dr), ("PASS_SINGLE_PRIMARY", 0))

        # Lost-update drift (nodes agree on 80, expected 100)
        with patch.object(b1, "pq", side_effect=["100", "80", "80", "5", "80", "80", "5"]):
            st, dr, _ = b1.conv_chk("citus", 5, ["n1", "n2"], 5432, "u", "p")
        self.assertEqual((st, dr), ("EXPECTED_LIMITATION_LOST_UPDATE", -20))

        # Diverged nodes
        with patch.object(b1, "pq", side_effect=["100", "90", "90", "5", "70", "70", "5"]):
            st, _, _ = b1.conv_chk("citus", 5, ["n1", "n2"], 5432, "u", "p")
        self.assertEqual(st, "EXPECTED_LIMITATION_DIVERGED")

    def test_run_sb_parsing_and_fallback(self):
        sb_out = (
            "    transactions:                        1200   (60.00 per sec.)\n"
            "    queries:                             24000  (1200.00 per sec.)\n"
            "    ignored errors:                      3      (0.15 per sec.)\n"
            "         avg:                                   133.25\n"
            "         95th percentile:                       210.50\n"
        )
        # Prepare failure -> EXPECTED_LIMITATION_UNSUPPORTED
        with patch.object(b1, "bc", side_effect=[
            sp.CompletedProcess([], 0, "", ""),
            sp.CompletedProcess([], 1, "", ""),
            sp.CompletedProcess([], 0, "err line1\nerr line2", ""),
        ]):
            r = b1.run_sb("yugabyte", "h1", 5433, "u", "p", 10, io.StringIO())
        self.assertEqual(r["convergence_status"], "EXPECTED_LIMITATION_UNSUPPORTED")
        self.assertIn("prepare:", r["notes"])

        # Auto ps fails, --db-ps-mode=disable succeeds -> parsed metrics
        with patch.object(b1, "bc", side_effect=[
            sp.CompletedProcess([], 0, "", ""),  # cleanup
            sp.CompletedProcess([], 0, "", ""),  # prepare
            sp.CompletedProcess([], 1, "", ""),  # run auto ps fails
            sp.CompletedProcess([], 0, "", ""),  # run ps disable ok
            sp.CompletedProcess([], 0, sb_out, ""),  # cat output
            sp.CompletedProcess([], 0, "", ""),  # final cleanup
        ]):
            r = b1.run_sb("cockroach", "h1", 26257, "root", "", 10, io.StringIO())
        self.assertEqual(r["convergence_status"], "PASS")
        self.assertEqual(r["tps"], 60.0)
        self.assertEqual(r["qps"], 1200.0)
        self.assertEqual(r["tx_committed"], 1200)
        self.assertEqual(r["tx_failed"], 3)
        self.assertEqual(r["lat_p95_ms"], 210.5)
        self.assertIn("--db-ps-mode=disable", r["notes"])


class TestBenchPgV2Lib(unittest.TestCase):
    def test_assert_zero_poc_containers(self):
        with patch.object(b2, "sh", return_value=sp.CompletedProcess([], 0, "other_app\n", "")):
            b2.assert_zero_poc_containers()
        with patch.object(b2, "sh", return_value=sp.CompletedProcess([], 0, "pg17_primary\nbench_client\n", "")):
            with self.assertRaises(RuntimeError) as ctx:
                b2.assert_zero_poc_containers()
            self.assertIn("pg17_primary", str(ctx.exception))

    def test_pb_run_v2_single_primary_routing(self):
        with patch.object(b2, "pb_run", return_value=(1.0, 2.0, 0.5, 3.0, 10, 0, 0)) as m_pb:
            b2.pb_run_v2("pg17-sync-streaming", "B_disjoint_rw", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
            self.assertEqual(m_pb.call_args.args[8], ["n1", "n1"])
            b2.pb_run_v2("pg17-sync-streaming", "C_multinode_ro", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
            self.assertEqual(m_pb.call_args.args[8], ["n1", "n2"])

    def test_csv_append_preserving_and_upsert_modular(self):
        r_a = b1.row("topoA", "S1", 10, 8, 20, 100, 0, 1, 0, 2, 10, 0, 0, "PASS", 0, "a")
        r_b1 = b1.row("topoB", "S2", 10, 8, 20, 200, 0, 1, 0, 2, 20, 0, 0, "PASS", 0, "b2")
        r_b2 = b1.row("topoB", "S1", 10, 8, 20, 250, 0, 1, 0, 2, 25, 0, 0, "PASS", 0, "b1")
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            p = Path(tmp) / "summary.csv"
            b2.upsert_modular_csv(p, "topoB", [r_b1], ["topoA", "topoB"], ["S1", "S2"])
            b2.upsert_modular_csv(p, "topoA", [r_a], ["topoA", "topoB"], ["S1", "S2"])
            b2.upsert_modular_csv(p, "topoB", [r_b1, r_b2], ["topoA", "topoB"], ["S1", "S2"])
            with p.open(encoding="utf-8") as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual([(r["topology"], r["suite"]) for r in rows], [("topoA", "S1"), ("topoB", "S1"), ("topoB", "S2")])

            b2.append_summary_preserving(p, "topoB", [r_b2])
            with p.open(encoding="utf-8") as fh:
                rows2 = list(csv.DictReader(fh))
            self.assertEqual([(r["topology"], r["suite"]) for r in rows2], [("topoA", "S1"), ("topoB", "S1")])


class TestPgExtendedLib(unittest.TestCase):
    def setUp(self):
        self.node = {"ct": "n1", "host": "h1", "port": 5432, "user": "u", "pw": "secret"}

    def test_dexec_pq_raw_and_pq(self):
        self.assertEqual(ext._dexec(self.node, ["psql"], True), ["docker", "exec", "-i", "-e", "PGPASSWORD=secret", "ext_client", "psql"])
        nopw = {**self.node, "pw": ""}
        self.assertNotIn("-e", ext._dexec(nopw, ["psql"], False))

        with patch("test_pg_extended_lib.sp.run", return_value=sp.CompletedProcess([], 1, "", "ERROR:  23503: fk violation")):
            rc, out, err, ss = ext.pq_raw(self.node, "INSERT 1")
        self.assertEqual((rc, ss), (1, "23503"))

        with patch("test_pg_extended_lib.sp.run", side_effect=sp.TimeoutExpired(["psql"], 5)):
            self.assertEqual(ext.pq_raw(self.node, "SELECT 1", to=5), (124, "", "TIMEOUT", "TIMEOUT"))

        with patch.object(ext, "pq_raw", return_value=(1, "", "bad sql", "42601")):
            with self.assertRaises(RuntimeError):
                ext.pq(self.node, "BAD")

    def test_wait_eq_wait_ready_and_probes(self):
        with patch.object(ext, "pq_raw", side_effect=[(0, "0", "", ""), (0, "1", "", "")]), patch("test_pg_extended_lib.time.sleep"):
            ok, _ = ext.wait_eq(self.node, "SELECT 1", "1", to_s=5.0)
        self.assertTrue(ok)

        with patch.object(ext, "pq_raw", return_value=(0, "1", "", "")):
            ext.wait_ready(self.node, to_s=5.0)

        with patch.object(ext, "pq", return_value=""):
            res = ext.run_t11_bulk("single", [self.node], set())
        self.assertIn("PASS:", res)
        self.assertIn("single-view", res)

        with patch.object(ext, "pq_raw", return_value=(0, "", "", "")), \
             patch.object(ext, "pq", side_effect=["65536|abcdef123456", "65536|abcdef123456"]), \
             patch.object(ext, "wait_eq", return_value=(True, 1.0)):
            fid = ext.run_t14_fidelity("birep", [self.node, {**self.node, "ct": "n2"}], set())
        self.assertIn("PASS: 2/2 identical md5=abcdef12", fid)


class TestBenchPgOptimizedLib(unittest.TestCase):
    def test_expected_suites_318_and_zero_containers(self):
        self.assertEqual(len(bopt.TOPO_ORDER), 18)
        self.assertEqual(sum(len(bopt.expected_suites(t)) for t in bopt.TOPO_ORDER), 318)
        self.assertEqual(len(bopt.expected_suites("pg18-standalone")), 15)
        with patch.object(boc, "sh", return_value=sp.CompletedProcess([], 0, "lp_pg18_user_1\ntradingai\n", "")):
            bopt.assert_zero_opt_containers()
        for bad in ("haproxy_yugabyte\n", "crdb_node1\n", "yt2\n", "bench_client\n"):
            with patch.object(boc, "sh", return_value=sp.CompletedProcess([], 0, bad, "")):
                with self.assertRaises(RuntimeError):
                    bopt.assert_zero_opt_containers()

    def test_completed_topologies_and_upsert_opt_csv(self):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            p = Path(tmp) / "benchmark_optimized.csv"
            self.assertEqual(bopt.completed_topologies(p), set())
            bopt.upsert_opt_csv(p, "cockroach-rc", [bopt.row("cockroach-rc", s, 20, 8, 15, 10, "N/A", 1, 0, 2, 100, 0, 0, "PASS", 0, "ok") for s in bopt.expected_suites("cockroach-rc")[:-1]])
            self.assertEqual(bopt.completed_topologies(p), set())
            bopt.upsert_opt_csv(p, "pg18-standalone", [bopt.row("pg18-standalone", s, 20, 8, 15, 500, "N/A", 2, 0, 4, 5000, 0, 0, "PASS", 0, "ok") for s in bopt.expected_suites("pg18-standalone")])
            self.assertEqual(bopt.completed_topologies(p), {"pg18-standalone"})
            bopt.upsert_opt_csv(p, "pg17-standalone", [bopt.row("pg17-standalone", "A_single_rw", 20, 8, 15, 400, "N/A", 2, 0, 4, 4000, 0, 0, "PASS", 0, "ok")])
            with p.open(encoding="utf-8", newline="") as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual(rows[0]["topology"], "pg17-standalone")
            self.assertEqual(rows[-1]["topology"], "cockroach-rc")

    def test_init_ds_opt_engine_specific_paths(self):
        calls = []
        with patch.object(bopt, "pq", side_effect=lambda *a: (calls.append(("pq", a[0], a[4])), "1")[1]), \
             patch.object(bopt, "bc", side_effect=lambda *a: calls.append(("bc", a[0]))), \
             patch.object(bopt, "sh", side_effect=lambda *a: calls.append(("sh", a[0]))), \
             patch.object(bopt, "bctl"), patch.object(bopt, "wcnt_opt"), \
             patch.object(bow, "pq", side_effect=lambda *a: calls.append(("ypq", a[0], a[4]))), \
             patch.object(bopt, "time") as mt:
            mt.sleep = lambda *_: None
            bopt.init_ds_opt("citus", ["citus_coord"], 5432, "postgres", "pw", 20, 2000000)
            citus_sql = [c[2] for c in calls if c[0] == "pq"]
            self.assertIn("DROP TABLE IF EXISTS pgbench_history CASCADE;", citus_sql)
            self.assertTrue(any("colocate_with=>'pgbench_accounts'" in s for s in citus_sql))
            self.assertTrue(any("fillfactor=90" in s for s in citus_sql))

            calls.clear()
            bopt.init_ds_opt("yugabyte", ["yb-node1"], 5433, "yugabyte", "", 1, 100000)
            yb_sql = "\n".join(c[2] for c in calls if c[0] == "pq")
            self.assertIn("ALTER SEQUENCE pgbench_history_hid_seq CACHE 1000;", yb_sql)
            self.assertIn("ANALYZE pgbench_branches;", yb_sql)
            self.assertFalse(any(c[0] == "bc" for c in calls))

            calls.clear()
            bopt.init_ds_opt("cockroach-rc", ["crdb_node1"], 26257, "bench", "", 1, 100000)
            crdb_sql = "\n".join(c[2] for c in calls if c[0] == "pq")
            self.assertIn("(g-1)//100000+1", crdb_sql)
            self.assertIn("fillfactor=90", crdb_sql)

            calls.clear()
            bopt.init_ds_opt("pgedge", ["pgedge_node1", "pgedge_node2"], 5432, "postgres", "pw", 1, 100000)
            self.assertTrue(any("spock.delta_apply" in c[2] for c in calls if c[0] == "pq"))

            calls.clear()
            bopt.init_ds_opt("bucardo", ["bucardo_node1", "bucardo_node2"], 5432, "postgres", "pw", 1, 100000)
            self.assertTrue(any("quick_delta_check=1" in " ".join(c[1]) for c in calls if c[0] == "sh"))
            self.assertTrue(any("autokick=1" in " ".join(c[1]) for c in calls if c[0] == "sh"))

            calls.clear()
            bopt.init_ds_opt("yt-cluster-async", ["yt1", "yt2", "yt3"], 5432, "postgres", "pw", 1, 100000, yt_am=True)
            self.assertTrue(any("uuidv7()" in c[2] for c in calls if c[0] == "pq"))
            self.assertTrue(any(bow.YT_ASYNC_CFG in c[2] for c in calls if c[0] == "ypq"))

    def test_reset_ds_opt_sysbench_retry_and_wan_netem_cleanup(self):
        rst_calls = []
        with patch.object(bow, "pq", side_effect=lambda *a: (rst_calls.append((a[0], a[4])), "5")[1]), \
             patch.object(bow, "wcnt_opt"), patch.object(bow, "time"):
            bopt.reset_ds_opt("pgedge", ["n1", "n2", "n3"], 5432, "postgres", "pw")
        updates = [q for h, q in rst_calls if "UPDATE pgbench_accounts" in q]
        self.assertEqual(len(updates), 1)
        self.assertEqual(rst_calls[-1][0], "n1")

        sb_out = "transactions: 500 (50.00 per sec.)\nqueries: 10000 (1000.00 per sec.)\nignored errors: 4 (0.40 per sec.)\navg: 20.0\n95th percentile: 45.0\n"
        cmds = []
        def fake_bc(a, pw="", chk=True):
            cmds.append(" ".join(a))
            return sp.CompletedProcess(a, 0, sb_out if a == ["cat", "/tmp/sb_r.out"] else "", "")
        with patch.object(bow, "bc", side_effect=fake_bc), patch.object(bow, "pq", return_value="1"), \
             patch.object(bow, "de", return_value=sp.CompletedProcess([], 0, "", "")), \
             patch.object(bow, "yt_setup_opt"), patch.object(bow.sp, "run"), patch.object(bow, "time"):
            res = bopt.run_sysbench_opt("yt-cluster-async", ["yt1", "yt2"], 5432, "postgres", "pw", 20, [("E_sysbench_oltp_rw", "oltp_read_write", 8, 15, True), ("E3_sysbench_oltp_wo", "oltp_write_only", 8, 12, False)], sb_sz=25000, yt_am=True)
        self.assertEqual(res["E_sysbench_oltp_rw"]["retries_40001"], 4)
        self.assertEqual(sum(1 for c in cmds if "sysbench oltp_read_write" in c and "prepare" in c), 2)
        self.assertTrue(any("/tmp/sb_wrap.lua" in c and "--table-size=25000" in c for c in cmds))

        tc_ops = []
        with patch.object(bow, "reset_ds_opt"), \
             patch.object(bow, "_tc", side_effect=lambda pc, img, args, chk=True: tc_ops.append((pc, args[0]))), \
             patch.object(bow, "pb_run_opt", side_effect=RuntimeError("abort")), patch.object(bow, "time"):
            with self.assertRaises(RuntimeError):
                bopt.run_wan_netem_opt("citus", 25, 12, ["citus_coord"], 5432, "postgres", "pw", 20, ["citus_worker1", "citus_worker2"], "img")
        self.assertEqual(tc_ops, [("citus_worker1", "replace"), ("citus_worker2", "replace"), ("citus_worker1", "del"), ("citus_worker2", "del")])

    def test_sb_prepare_skips_bucardo_slave_wait(self):
        with patch.object(bow, "_sb_cleanup"), \
             patch.object(bow, "bc", return_value=sp.CompletedProcess([], 0, "", "")), \
             patch.object(bow, "wcnt_opt") as m_wcnt:
            for topo, hosts in (
                ("bucardo", ["bucardo_node1", "bucardo_node2"]),
                ("yugabyte", ["yb-node1", "yb-node2", "yb-node3"]),
                ("cockroach-rc", ["crdb_node1", "crdb_node2", "crdb_node3"]),
            ):
                self.assertEqual(bow._sb_prepare(topo, hosts, 5432, "postgres", "pw", "--tables=4", 25000, False), 0)
            m_wcnt.assert_not_called()

            self.assertEqual(bow._sb_prepare("pgedge", ["pgedge_node1", "pgedge_node2", "pgedge_node3"], 5432, "postgres", "pw", "--tables=4", 25000, False), 0)
            self.assertEqual([c.args[0] for c in m_wcnt.call_args_list], ["pgedge_node2", "pgedge_node3"])

    def test_optimized_runner_sources_dotenv_before_pg_pass(self):
        runner = Path(__file__).resolve().parent.parent / "scripts" / "bench_pg_optimized_runner.sh"
        src = runner.read_text(encoding="utf-8")
        dotenv_stmt = "[ -f .env ] && { set -a; . ./.env; set +a; }"
        self.assertIn(dotenv_stmt, src)
        self.assertLess(src.index('cd "$BENCH_ROOT"'), src.index(dotenv_stmt))
        self.assertLess(src.index(dotenv_stmt), src.index("export PG_PASS="))
        if not shutil.which("bash"):
            return
        prologue = "\n".join(src.splitlines()[: src.splitlines().index("exec python3 - \"$@\" <<'PY'")])
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            (root / "sub").mkdir()
            (root / ".env").write_text("DB_ROOT_PASSWORD=dotenv_secret_check\n", encoding="utf-8", newline="\n")
            (root / "scripts" / "env_probe.sh").write_text(
                prologue + '\nprintf "%s|%s|%s" "$PG_PASS" "$DB_ROOT_PASSWORD" "$PG_LAB_PASSWORD"\n',
                encoding="utf-8",
                newline="\n",
            )
            env = {k: v for k, v in os.environ.items() if k not in ("DB_ROOT_PASSWORD", "PG_LAB_PASSWORD", "PG_PASS")}
            env["PG_LAB_PASSWORD"] = "stale_shell_override"
            res = sp.run(["bash", "../scripts/env_probe.sh"], cwd=root / "sub", env=env, capture_output=True, text=True, check=True)
            self.assertEqual(res.stdout, "dotenv_secret_check|dotenv_secret_check|dotenv_secret_check")


class TestBenchPg18Lib(unittest.TestCase):
    def test_assert_zero_pg18_containers(self):
        with patch.object(b18, "sh", return_value=sp.CompletedProcess([], 0, "other_app\npg17_standalone\n", "")):
            b18.assert_zero_pg18_containers()
        for bad in ("pg18_stream_primary\n", "haproxy_pg18_proxy\n", "bench_client\n"):
            with patch.object(b18, "sh", return_value=sp.CompletedProcess([], 0, bad, "")):
                with self.assertRaises(RuntimeError) as ctx:
                    b18.assert_zero_pg18_containers()
                self.assertIn(bad.strip(), str(ctx.exception))

    def test_pb_run_pg18_routing(self):
        with patch.object(b18, "pb_run", return_value=(1.0, 2.0, 0.5, 3.0, 10, 0, 0)) as m_pb:
            for topo in ("pg18-async-streaming", "pg18-sync-streaming", "pg18-logical"):
                b18.pb_run_pg18(topo, "B1_disjoint_rw", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
                self.assertEqual(m_pb.call_args.args[8], ["n1", "n1"])
                b18.pb_run_pg18(topo, "C_multinode_ro", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
                self.assertEqual(m_pb.call_args.args[8], ["n1", "n2"])
            b18.pb_run_pg18("pg18-birep", "B1_disjoint_rw", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
            self.assertEqual(m_pb.call_args.args[8], ["n1", "n2"])
            b18.pb_run_pg18("pg18-birep", "C_multinode_ro", 2, 4, 2, 5, "a1", "a2", ["n1", "n2"], 5432, "u", "p")
            self.assertEqual(m_pb.call_args.args[8], ["n1", "n2"])

    def test_upsert_pg18_csv_ordering_and_idempotency(self):
        topos = ["pg18-standalone", "pg18-birep"]
        suites = ["S1", "S2"]
        r_sa = b1.row("pg18-standalone", "S1", 2, 8, 20, 100, "N/A", 1, 0, 2, 10, 0, 0, "PASS_SINGLE_PRIMARY", 0, "sa")
        r_b2 = b1.row("pg18-birep", "S2", 2, 8, 20, 200, "N/A", 1, 0, 2, 20, 0, 0, "PASS_CONVERGED", 0, "b2")
        r_b1 = b1.row("pg18-birep", "S1", 2, 8, 20, 250, "N/A", 1, 0, 2, 25, 0, 0, "PASS_CONVERGED", 0, "b1")
        r_b1_new = b1.row("pg18-birep", "S1", 2, 8, 20, 300, "N/A", 1, 0, 2, 30, 0, 0, "PASS_CONVERGED", 0, "b1_updated")
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            p = Path(tmp) / "benchmark_pg18.csv"
            b18.upsert_pg18_csv(p, "pg18-birep", [r_b2, r_b1], topos, suites)
            b18.upsert_pg18_csv(p, "pg18-standalone", [r_sa], topos, suites)
            b18.upsert_pg18_csv(p, "pg18-birep", [r_b1_new, r_b2], topos, suites)
            with p.open(encoding="utf-8", newline="") as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual(
                [(r["topology"], r["suite"], r["notes"]) for r in rows],
                [
                    ("pg18-standalone", "S1", "sa"),
                    ("pg18-birep", "S1", "b1_updated"),
                    ("pg18-birep", "S2", "b2"),
                ],
            )


class TestBenchResourceHygiene(unittest.TestCase):
    def test_upsert_csv_emits_no_resource_warnings(self):
        topos = ["topoA", "topoB"]
        suites = ["S1", "S2"]
        r1 = b1.row("topoA", "S1", 2, 8, 20, 100, "N/A", 1, 0, 2, 10, 0, 0, "PASS", 0, "r1")
        r2 = b1.row("topoA", "S2", 2, 8, 20, 150, "N/A", 1, 0, 2, 15, 0, 0, "PASS", 0, "r2")
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            p_v2 = Path(tmp) / "v2.csv"
            p_18 = Path(tmp) / "pg18.csv"
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always", ResourceWarning)
                b2.upsert_modular_csv(p_v2, "topoA", [r1], topos, suites)
                b2.upsert_modular_csv(p_v2, "topoA", [r1, r2], topos, suites)
                b18.upsert_pg18_csv(p_18, "topoA", [r1], topos, suites)
                b18.upsert_pg18_csv(p_18, "topoA", [r1, r2], topos, suites)
                gc.collect()
        res_warnings = [f"{w.filename}:{w.lineno}: {w.message}" for w in caught if issubclass(w.category, ResourceWarning)]
        self.assertEqual(res_warnings, [])

    def test_scripts_open_calls_use_context_managers(self):
        scripts_dir = Path(__file__).resolve().parent.parent / "scripts"
        targets = sorted(scripts_dir.glob("*.py")) + sorted(scripts_dir.glob("*.sh"))
        self.assertGreater(len(targets), 0)
        offenders = []
        for path in targets:
            for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                stripped = line.lstrip()
                if stripped.startswith("#") or ".open(" not in line:
                    continue
                if not re.match(r"^with\b", stripped):
                    offenders.append(f"{path.name}:{lineno}: {stripped}")
        self.assertEqual(offenders, [], "Ungoverned .open() calls found:\n" + "\n".join(offenders))


if __name__ == "__main__":
    unittest.main()
