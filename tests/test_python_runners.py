import os, sys, unittest, tempfile, string, argparse
from unittest.mock import patch, MagicMock
import interactive_runner, mysql_docker

class TestInteractiveRunner(unittest.TestCase):
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
             patch('builtins.input', side_effect=['y', 'c', 'n']), \
             patch('builtins.print'):
            interactive_runner.main()
        self.assertEqual(run_mock.call_count, 1)

class TestMySQLDocker(unittest.TestCase):
    def test_secrets_module(self):
        self.assertFalse(hasattr(mysql_docker, 'random'))
        self.assertTrue(hasattr(mysql_docker, 'secrets'))
        pwd = mysql_docker.generate_password(64)
        self.assertEqual(len(pwd), 64)
        self.assertTrue(all(c in string.ascii_letters + string.digits for c in pwd))

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
