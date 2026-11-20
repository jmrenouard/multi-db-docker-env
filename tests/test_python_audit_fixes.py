import io, os, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import bench_pg_lib, interactive_runner, mysql_docker


class TestPythonAuditFixes(unittest.TestCase):
    def test_bench_pg_lib_passes_chk_false_not_pw(self):
        calls = []
        def fake_de(ct, a, pw="", chk=True):
            calls.append((a, pw, chk))
            return MagicMock(returncode=1 if "prepare" in " ".join(a) else 0, stdout="unsupported")
        with patch.object(bench_pg_lib, "de", side_effect=fake_de):
            out = bench_pg_lib.run_sb("cockroach", "cr1", 26257, "root", "", 10, io.StringIO())
        self.assertEqual(out["convergence_status"], "EXPECTED_LIMITATION_UNSUPPORTED")
        prep = [c for c in calls if "prepare" in " ".join(c[0])]
        self.assertEqual((prep[0][1], prep[0][2]), ("", False))

    def test_interactive_runner_postgres_target_and_html_escape(self):
        with patch("builtins.input", side_effect=["1", "4", "1"]), patch("builtins.print"):
            title, steps = interactive_runner.get_steps()
        self.assertIn("PostgreSQL 17", title)
        self.assertEqual(next(s for s in steps if s["id"] == "start")["command"], "make postgres17")
        with tempfile.TemporaryDirectory() as tmp:
            rpt = os.path.join(tmp, "report.html")
            res = [{"id": "s1", "name": "S1", "description": "D", "command": "echo <script>x</script>", "status": "RUNNING", "stdout": "<b>ok</b>", "stderr": "<err>"}]
            with patch.object(interactive_runner, "REPORT_FILE", rpt), patch("builtins.print"):
                interactive_runner.generate_report(res, finished=False)
            html = Path(rpt).read_text(encoding="utf-8")
        self.assertIn("&lt;b&gt;ok&lt;/b&gt;", html)
        self.assertIn("&lt;err&gt;", html)
        self.assertIn("echo &lt;script&gt;x&lt;/script&gt;", html)
        self.assertNotIn("<script>x</script>", html)

    def test_mysql_docker_security_list_and_rm(self):
        buf = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp:
            orig = os.getcwd()
            os.chdir(tmp)
            try:
                with patch("os.chmod") as m_chmod, patch("sys.stdout", buf):
                    mysql_docker.generate_bash_alias("mydb", 3307, "SuperSecret99")
                m_chmod.assert_called_once_with("mysql.bashrc", 0o600)
                self.assertNotIn("SuperSecret99", buf.getvalue())
                cnt = MagicMock(image=MagicMock(tags=["mysql:8.4"]))
                cli = MagicMock()
                cli.containers.get.return_value = cnt
                with patch("builtins.print"):
                    mysql_docker.remove_environment("mydb", docker_client=cli)
                cnt.remove.assert_called_once_with(force=True)
                cli.images.remove.assert_not_called()
            finally:
                os.chdir(orig)
        stopped = MagicMock(status="exited", image=MagicMock(tags=["mysql:8.4"]), attrs={"NetworkSettings": {"Ports": None}})
        stopped.name = "db_stopped"
        running = MagicMock(status="running", image=MagicMock(tags=["mysql:8.4"]), attrs={"NetworkSettings": {"Ports": {"3306/tcp": [{"HostPort": "3307"}]}}})
        running.name = "db_running"
        cli = MagicMock()
        cli.containers.list.return_value = [stopped, running]
        buf2 = io.StringIO()
        with patch.object(mysql_docker, "from_env", return_value=cli), patch("sys.stdout", buf2):
            mysql_docker.list_containers(status_filter="stopped")
        self.assertIn("db_stopped", buf2.getvalue())
        self.assertNotIn("db_running", buf2.getvalue())


if __name__ == "__main__":
    unittest.main()
