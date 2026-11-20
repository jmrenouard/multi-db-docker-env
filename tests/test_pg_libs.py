"""Deterministic unit tests for PG benchmark and extended test libraries."""
import csv
import io
import subprocess as sp
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS_DIR = str(Path(__file__).resolve().parent.parent / "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import bench_pg_lib as b1
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
        with tempfile.TemporaryDirectory() as tmp:
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


if __name__ == "__main__":
    unittest.main()
