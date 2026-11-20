import os, sys, unittest, tempfile, string, argparse, io, types
from unittest.mock import patch, MagicMock
import interactive_runner, mysql_docker

class TestInteractiveRunner(unittest.TestCase):
    def tearDown(self):
        interactive_runner.L = 'en'

    def test_operator_precedence(self):
        cases = [('en', 'y', False), ('en', 'n', True), ('fr', 'o', False), ('fr', 'n', True)]
        for lang, val, exp in cases:
            self.assertEqual(val.lower() != ('o' if lang == 'fr' else 'y'), exp)

    def test_run_command_large_stderr(self):
        cmd = f'"{sys.executable}" -c "import sys; sys.stderr.write(\'E\'*131072); sys.stdout.write(\'OK\\n\')"'
        with patch('builtins.print'):
            code, out, err = interactive_runner.run_command(cmd)
        self.assertEqual(code, 0)
        self.assertEqual(len(err), 131072)

    def test_interactive_failure_stops_pipeline(self):
        steps = [{"id": "s1", "name": "s1", "command": "c1", "description": "d1"}, {"id": "s2", "name": "s2", "command": "c2", "description": "d2"}]
        run_mock = MagicMock(return_value=(1, "out", "err"))
        with patch('argparse.ArgumentParser.parse_args', return_value=argparse.Namespace(auto=False, interactive=True, lang='en')), \
             patch.object(interactive_runner, 'get_steps', return_value=('standalone', steps)), \
             patch.object(interactive_runner, 'run_command', run_mock), \
             patch.object(interactive_runner, 'generate_report'), \
             patch('builtins.input', side_effect=['y', 'c', 'n']), \
             patch('builtins.print'):
            interactive_runner.main()
        self.assertEqual(run_mock.call_count, 1)

    def test_select_language(self):
        with patch('builtins.input', return_value='f'):
            interactive_runner.select_language()
        self.assertEqual(interactive_runner.L, 'fr')
        interactive_runner.L = 'en'
        with patch('builtins.input', side_effect=EOFError):
            interactive_runner.select_language()
        self.assertEqual(interactive_runner.L, 'en')

    def test_get_steps_all_branches(self):
        label, steps = interactive_runner.get_steps(auto=True)
        self.assertIn("MariaDB 11.4", label)
        self.assertEqual(len(steps), 5)
        with patch('builtins.print'), patch('builtins.input', return_value='2'):
            lbl, st = interactive_runner.get_steps(auto=False)
        self.assertIn("Galera", lbl)
        self.assertEqual(st[1]["command"], "make up-galera")
        with patch('builtins.print'), patch('builtins.input', return_value='3'):
            lbl, st = interactive_runner.get_steps(auto=False)
        self.assertIn("Replication", lbl)
        self.assertEqual(st[2]["command"], "make setup-repli")
        with patch('builtins.print'), patch('builtins.input', side_effect=['1', '2', '2']):
            lbl, st = interactive_runner.get_steps(auto=False)
        self.assertIn("MySQL 8.4", lbl)
        self.assertEqual(st[1]["command"], "make mysql84")
        with patch('builtins.print'), patch('builtins.input', side_effect=['1', 'bad']):
            lbl, st = interactive_runner.get_steps(auto=False)
        self.assertIn("MariaDB 11.4", lbl)

    def test_supported_and_eol_versions(self):
        versions = interactive_runner.SUPPORTED_VERSIONS
        self.assertEqual(set(versions["MariaDB"]), {"10.11", "11.4", "11.8", "12.3"})
        self.assertEqual(set(versions["MySQL"]), {"8.4", "9.7"})
        self.assertEqual(set(versions["Percona"]), {"8.4"})
        self.assertEqual(set(versions["PostgreSQL"]), {"15", "16", "17", "18"})
        for engine, eol_vers in [("MySQL", ["5.7", "8.0", "9.6"]), ("MariaDB", ["10.6"]), ("Percona", ["8.0"])]:
            for eol in eol_vers:
                self.assertNotIn(eol, versions[engine], f"EOL {engine} {eol} must not be offered")

        cases = [
            (['1', '1', '1'], "MariaDB 12.3", "make mariadb123"),
            (['1', '2', '1'], "MySQL 9.7", "make mysql97"),
            (['1', '3', '1'], "Percona 8.4", "make percona84"),
            (['1', '4', '1'], "PostgreSQL 18", "make postgres18"),
            (['1', '4', '4'], "PostgreSQL 15", "make postgres15"),
        ]
        for inputs, expected_label, expected_cmd in cases:
            with self.subTest(target=expected_cmd):
                with patch('builtins.print'), patch('builtins.input', side_effect=inputs):
                    lbl, st = interactive_runner.get_steps(auto=False)
                self.assertIn(expected_label, lbl)
                self.assertEqual(st[1]["command"], expected_cmd)

    def test_generate_report_all_statuses(self):
        results = [
            {"id": "s1", "name": "S1", "description": "d1", "command": "c1", "status": "SUCCESS", "stdout": "ok", "stderr": ""},
            {"id": "s2", "name": "S2", "description": "d2", "command": "c2", "status": "FAILED", "stdout": "", "stderr": "boom"},
            {"id": "s3", "name": "S3", "description": "d3", "command": "c3", "status": "RUNNING", "stdout": "", "stderr": ""},
            {"id": "s4", "name": "S4", "description": "d4", "command": "c4", "status": "PENDING", "stdout": "", "stderr": ""},
            {"id": "s5", "name": "S5", "description": "d5", "command": "c5", "status": "SKIPPED", "stdout": "", "stderr": ""},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            rpt = os.path.join(tmp, "reports", "run_report.html")
            with patch.object(interactive_runner, 'REPORT_FILE', rpt), patch('builtins.print'):
                interactive_runner.generate_report(results, finished=True)
            with open(rpt, encoding="utf-8") as f:
                html = f.read()
        self.assertIn("data-finished", html)
        self.assertIn("boom", html)
        self.assertIn("status-success", html)
        self.assertIn("status-failure", html)

    def test_main_auto_and_interactive_skip(self):
        steps = [{"id": "s1", "name": "s1", "command": "c1", "description": "d1"}]
        with patch('argparse.ArgumentParser.parse_args', return_value=argparse.Namespace(auto=True, interactive=False, lang='en')), \
             patch.object(interactive_runner, 'get_steps', return_value=('auto', steps)), \
             patch.object(interactive_runner, 'run_command', return_value=(0, "ok", "")) as run_m, \
             patch.object(interactive_runner, 'generate_report') as rep_m, \
             patch('builtins.print'):
            interactive_runner.main()
        run_m.assert_called_once()
        self.assertTrue(rep_m.call_args.kwargs.get("finished"))

        with patch('argparse.ArgumentParser.parse_args', return_value=argparse.Namespace(auto=False, interactive=True, lang='en')), \
             patch.object(interactive_runner, 'get_steps', return_value=('inter', steps)), \
             patch.object(interactive_runner, 'run_command') as run_m2, \
             patch.object(interactive_runner, 'generate_report'), \
             patch('builtins.input', return_value='n'), \
             patch('builtins.print'):
            interactive_runner.main()
        run_m2.assert_not_called()

class TestMySQLDocker(unittest.TestCase):
    def test_secrets_module(self):
        self.assertFalse(hasattr(mysql_docker, 'random'))
        self.assertTrue(hasattr(mysql_docker, 'secrets'))
        pwd = mysql_docker.generate_password(64)
        self.assertEqual(len(pwd), 64)
        self.assertTrue(all(c in string.ascii_letters + string.digits for c in pwd))

    def test_find_free_port_and_config_helpers(self):
        port = mysql_docker.find_free_port()
        self.assertIsInstance(port, int)
        self.assertNotEqual(port, 3306)
        self.assertGreater(port, 0)
        with tempfile.TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                with patch('builtins.print'):
                    mysql_docker.create_my_cnf("dbtest", "admin", "s3cr3t", port=port)
                    mysql_docker.generate_bash_alias("dbtest", port, "s3cr3t")
                with open("dbtest.my.cnf", encoding="utf-8") as f:
                    cnf = f.read()
                self.assertIn("[client]", cnf)
                self.assertIn("user=admin", cnf)
                self.assertIn(f"port={port}", cnf)
                with open("mysql.bashrc", encoding="utf-8") as f:
                    rc = f.read()
                self.assertIn("export MYSQL_DEFAULTS_FILE_dbtest=", rc)
                self.assertIn("alias dbtest='docker exec", rc)
                mock_docker = MagicMock()
                mock_docker.containers.get.side_effect = Exception("Not found")
                with patch('builtins.print'):
                    mysql_docker.remove_environment("dbtest", docker_client=mock_docker)
                self.assertFalse(os.path.exists("dbtest.my.cnf"))
                self.assertFalse(os.path.exists("mysql.bashrc"))
            finally:
                os.chdir(orig)

    def test_launch_stop_list_and_cli_dispatch(self):
        class FakeNotFound(Exception): pass
        class FakeImgNotFound(Exception): pass
        fake_docker = types.SimpleNamespace(errors=types.SimpleNamespace(NotFound=FakeNotFound, ImageNotFound=FakeImgNotFound))

        # Already running, stopped->start, new container launch, stop
        running_c = MagicMock(status="running")
        stopped_c = MagicMock(status="exited")
        new_c = MagicMock()
        client = MagicMock()
        with patch.object(mysql_docker, 'docker', fake_docker), \
             patch.object(mysql_docker, 'from_env', return_value=client), \
             patch('builtins.print'):
            client.containers.get.return_value = running_c
            mysql_docker.launch_container("db1", "mysql", "8.4", "admin", "pw")
            running_c.start.assert_not_called()

            client.containers.get.return_value = stopped_c
            mysql_docker.launch_container("db1", "mysql", "8.4", "admin", "pw")
            stopped_c.start.assert_called_once()

            client.containers.get.side_effect = FakeNotFound("missing")
            client.containers.run.return_value = new_c
            with tempfile.TemporaryDirectory() as tmpdir:
                orig = os.getcwd()
                os.chdir(tmpdir)
                try:
                    mysql_docker.launch_container("dbnew", "mariadb", "11.4", "admin", None)
                    self.assertTrue(os.path.exists("dbnew.my.cnf"))
                    self.assertTrue(os.path.exists("mysql.bashrc"))
                finally:
                    os.chdir(orig)

            client.containers.get.side_effect = None
            client.containers.get.return_value = running_c
            mysql_docker.stop_container("db1")
            running_c.stop.assert_called_once()

        # list_containers filters DB images and status
        c1 = MagicMock(name="c1", status="running", image=MagicMock(tags=["mysql:8.4"]), attrs={"NetworkSettings": {"Ports": {"3306/tcp": [{"HostPort": "3307"}]}}})
        c1.name = "m1"
        c2 = MagicMock(name="c2", status="exited", image=MagicMock(tags=["nginx:latest"]), attrs={"NetworkSettings": {"Ports": {}}})
        c2.name = "web"
        client.containers.list.return_value = [c1, c2]
        buf = io.StringIO()
        with patch.object(mysql_docker, 'from_env', return_value=client), patch('sys.stdout', buf):
            mysql_docker.list_containers(status_filter="running")
        out = buf.getvalue()
        self.assertIn("m1", out)
        self.assertIn("3307", out)
        self.assertNotIn("web", out)

        # CLI main dispatch
        with patch.object(sys, 'argv', ['mysql_docker.py', 'stop', 'db1']), \
             patch.object(mysql_docker, 'stop_container') as m_stop:
            mysql_docker.main()
        m_stop.assert_called_once_with('db1', debug=False)

    def test_remove_env_resilience(self):
        mock_docker = MagicMock()
        mock_docker.containers.get.side_effect = Exception("Not found")
        cnt = MagicMock(image=MagicMock(tags=[]))
        mock_docker2 = MagicMock()
        mock_docker2.containers.get.return_value = cnt
        with tempfile.TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                mysql_docker.remove_environment("missing", docker_client=mock_docker)
                mysql_docker.remove_environment("untagged", docker_client=mock_docker2)
                cnt.remove.assert_called_once_with(force=True)
            finally:
                os.chdir(orig)

    def test_remove_env_preserves_overlapping_alias(self):
        mock_docker = MagicMock()
        mock_docker.containers.get.side_effect = Exception("Not found")
        with tempfile.TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                with open("mysql.bashrc", "w") as f:
                    f.write("export MYSQL_DEFAULTS_FILE_db1=p1\nalias db1='c1'\nalias db10='c10'\nexport MYSQL_DEFAULTS_FILE_db10=p10\n")
                mysql_docker.remove_environment("db1", docker_client=mock_docker)
                with open("mysql.bashrc") as f:
                    content = f.read()
                self.assertNotIn("alias db1=", content)
                self.assertNotIn("MYSQL_DEFAULTS_FILE_db1=", content)
                self.assertIn("alias db10='c10'", content)
                self.assertIn("MYSQL_DEFAULTS_FILE_db10=p10", content)
            finally:
                os.chdir(orig)

if __name__ == '__main__':
    unittest.main()
