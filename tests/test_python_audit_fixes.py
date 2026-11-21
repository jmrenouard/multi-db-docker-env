import io, os, subprocess, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bench_pg_lib, interactive_runner, mysql_docker, test_lab


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
        self.assertIn("PostgreSQL 18", title)
        self.assertEqual(next(s for s in steps if s["id"] == "start")["command"], "make postgres18")
        with patch("builtins.input", side_effect=["1", "3", "1"]), patch("builtins.print"):
            p_title, p_steps = interactive_runner.get_steps()
        self.assertIn("Percona 8.4", p_title)
        self.assertEqual(next(s for s in p_steps if s["id"] == "start")["command"], "make percona84")
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

    def test_lab_query_timeouts(self):
        lab = test_lab.TestDatabaseLab("test_version")
        lab.db_root_password = "rootpass"
        calls = []

        def fake_timeout(cmd, **kw):
            calls.append((cmd, kw))
            raise subprocess.TimeoutExpired(cmd, kw.get("timeout", 5))

        with patch.dict(os.environ, {"TRAEFIK_MYSQL_PORT": "13306", "TRAEFIK_PG_PORT": "15432"}), patch.object(test_lab.subprocess, "run", side_effect=fake_timeout):
            res_my = lab.run_mysql_query("SELECT 1")
            res_pg = lab.run_pg_query("SELECT 1;")
        self.assertEqual((res_my.returncode, res_pg.returncode), (-1, -1))
        self.assertIn("--connect-timeout=3", calls[0][0])
        self.assertIn("-P13306", calls[0][0])
        self.assertEqual(calls[0][1]["timeout"], 5)
        self.assertEqual(calls[1][1]["env"]["PGCONNECT_TIMEOUT"], "3")
        self.assertIn("15432", calls[1][0])
        self.assertEqual(calls[1][1]["timeout"], 5)

    def test_cluster_setup_and_sigkill_guards(self):
        root = Path(__file__).resolve().parent.parent
        innodb = (root / "docker-compose-innodb-cluster.yml").read_text(encoding="utf-8")
        self.assertIn("chmod 0644 /etc/mysql/conf.d/group_replication.cnf", innodb)
        self.assertNotIn(":/etc/mysql/conf.d/group_replication.cnf", innodb)
        buc = (root / "scripts/bucardo/setup_bucardo.sh").read_text(encoding="utf-8")
        self.assertIn("while docker exec bucardo_daemon test -f /var/run/bucardo/bucardo.mcp.pid", buc)
        yt_test = (root / "tests/test_yt_cluster.sh").read_text(encoding="utf-8")
        self.assertIn("[ -f .env ]", yt_test)
        self.assertIn("for i in range(15):", yt_test)
        self.assertIn("[ -f .env ]", (root / "scripts/yt_cluster/setup_yt_cluster.sh").read_text(encoding="utf-8"))
        self.assertIn("logging_collector = off", (root / "scripts/pgedge/setup_pgedge.sh").read_text(encoding="utf-8"))
        standalone = (root / "docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("x-pfs-command: &pfs-command", standalone)
        self.assertNotIn("pfs.cnf", standalone)
        galera = (root / "docker-compose-galera.yml").read_text(encoding="utf-8")
        self.assertIn("galera_data_01:/var/lib/mysql", galera)
        self.assertNotIn("gdatadir_01", galera)
        for i in (1, 2, 3):
            self.assertIn("gcache.size=128M", (root / f"conf/gcustom_{i}.cnf").read_text(encoding="utf-8"))
        admin = (root / "cmd/mdb/commands_admin.go").read_text(encoding="utf-8")
        self.assertIn('ctr+":/var/tmp/"', admin)
        self.assertNotIn('ctr+":/tmp/"', admin)


if __name__ == "__main__":
    unittest.main()
