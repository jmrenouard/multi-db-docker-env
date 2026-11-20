"""Deterministic static repository validation tests (compose, bash, VERSION, Makefile)."""
import re
import shutil
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def _git_ls_files(pattern: str) -> list[Path]:
    out = subprocess.check_output(["git", "ls-files", pattern], cwd=ROOT, text=True)
    return [ROOT / p for p in out.splitlines() if p.strip()]


class TestRepoStaticValidation(unittest.TestCase):
    def test_all_tracked_compose_files_are_valid_yaml(self):
        compose_files = _git_ls_files("docker-compose*.yml")
        self.assertGreaterEqual(len(compose_files), 15)
        for path in compose_files:
            with self.subTest(file=path.name):
                data = yaml.safe_load(path.read_text(encoding="utf-8"))
                self.assertIsInstance(data, dict)
                services = data.get("services")
                self.assertIsInstance(services, dict)
                self.assertGreater(len(services), 0)
                for svc_name, svc_cfg in services.items():
                    self.assertIsInstance(svc_cfg, dict, f"{path.name}:{svc_name}")
                    self.assertTrue(
                        "image" in svc_cfg or "build" in svc_cfg,
                        f"{path.name}:{svc_name} must define 'image' or 'build'",
                    )

    def test_all_tracked_shell_scripts_pass_bash_syntax_check(self):
        if not shutil.which("bash"):
            self.skipTest("bash not available on PATH")
        rels = [p.relative_to(ROOT).as_posix() for p in _git_ls_files("*.sh")]
        self.assertGreater(len(rels), 0)
        # Single bash process avoids per-file spawn overhead on Windows
        proc = subprocess.run(
            ["bash", "-c", 'rc=0; for f in "$@"; do bash -n "$f" || rc=1; done; exit $rc', "_", *rels],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, f"Bash syntax errors:\n{proc.stderr.strip()}")

    def test_version_semver_and_changelog_sync(self):
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        first_line = (ROOT / "Changelog").read_text(encoding="utf-8").splitlines()[0].strip()
        self.assertTrue(
            first_line.startswith(f"{version} "),
            f"Top Changelog header '{first_line}' does not start with VERSION '{version}'",
        )

    def test_makefile_referenced_scripts_exist(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        refs = sorted(set(re.findall(r"\./(scripts/[A-Za-z0-9_./-]+\.(?:sh|py))", makefile)))
        self.assertGreater(len(refs), 0)
        missing = [r for r in refs if not (ROOT / r).is_file()]
        self.assertEqual(missing, [], f"Makefile references missing scripts: {missing}")


if __name__ == "__main__":
    unittest.main()
