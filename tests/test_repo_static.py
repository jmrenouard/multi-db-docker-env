"""Deterministic static repository validation tests (compose, bash, VERSION, Makefile)."""
import re
import shutil
import subprocess
import unittest
from pathlib import Path

try:
    import yaml
except ImportError:  # stdlib fallback when PyYAML is not installed (e.g. bare CI)
    yaml = None

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
                text = path.read_text(encoding="utf-8")
                if yaml is None:
                    self.assertRegex(text, r"(?m)^services:\s*$")
                    self.assertRegex(text, r"(?m)^\s+(?:image|build):")
                    continue
                data = yaml.safe_load(text)
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

    def test_no_eol_images_and_pg18_volume_mount(self):
        eol_images = (
            "mysql:5.7",
            "mysql:8.0",
            "mysql:9.6",
            "mariadb:10.6",
            "percona/percona-server:8.0",
            "traefik:v2.11",
            "haproxy:2.9-alpine",
        )
        for path in _git_ls_files("docker-compose*.yml"):
            text = path.read_text(encoding="utf-8")
            for img in eol_images:
                with self.subTest(file=path.name, image=img):
                    pattern = rf"(?m)^\s*image:\s*['\"]?{re.escape(img)}(?:['\"\s#]|$)"
                    self.assertNotRegex(text, pattern, f"Decommissioned EOL image '{img}' found in {path.name}")

        compose_text = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        if yaml is not None:
            services = yaml.safe_load(compose_text).get("services", {})
            self.assertIn("postgres18", services, "postgres18 service missing from docker-compose.yml")
            volumes = [str(v) for v in services["postgres18"].get("volumes", [])]
            self.assertTrue(
                any(v.endswith(":/var/lib/postgresql") for v in volumes),
                f"postgres18 must mount /var/lib/postgresql, got: {volumes}",
            )
            self.assertFalse(
                any("/var/lib/postgresql/data" in v for v in volumes),
                f"postgres18 must not mount /var/lib/postgresql/data, got: {volumes}",
            )
        else:
            m = re.search(r"(?ms)^  postgres18:\n(.*?)(?=^  [A-Za-z0-9_-]+:|\Z)", compose_text)
            self.assertIsNotNone(m, "postgres18 service missing from docker-compose.yml")
            block = m.group(1)
            self.assertIn(":/var/lib/postgresql", block)
            self.assertNotIn(":/var/lib/postgresql/data", block)

    def test_pg_compose_durable_tunings_and_haproxy_ram_caps(self):
        pg17_files = ("docker-compose-pg17-baseline.yml", "docker-compose-pg-streaming.yml", "docker-compose-pg-logical.yml", "docker-compose-pg-birep.yml")
        pg18_files = ("docker-compose-pg18-streaming.yml", "docker-compose-pg18-logical.yml", "docker-compose-pg18-birep.yml", "docker-compose-yt-cluster.yml")
        mm_files = ("docker-compose-pgedge.yml", "docker-compose-bucardo.yml", "docker-compose-citus.yml", "docker-compose-yugabyte.yml", "docker-compose-cockroach.yml")
        for fname in pg17_files + pg18_files + mm_files:
            txt = (ROOT / fname).read_text(encoding="utf-8")
            self.assertNotRegex(txt, r"(?i)\b(?:fsync\s*=\s*off|full_page_writes\s*=\s*off|fs_sync\s*=\s*false)\b", fname)
        for fname in pg17_files:
            txt = (ROOT / fname).read_text(encoding="utf-8")
            self.assertNotIn("io_method", txt, fname)
        for fname in pg18_files:
            txt = (ROOT / fname).read_text(encoding="utf-8")
            self.assertIn("io_method", txt, fname)
            self.assertIn("io_workers", txt, fname)
        yt_txt = (ROOT / "docker-compose-yt-cluster.yml").read_text(encoding="utf-8")
        self.assertIn('YT_MAX_PREPARED: "${YT_MAX_PREPARED:-300}"', yt_txt)
        self.assertNotIn("shared_preload_libraries", yt_txt)
        self.assertIn('mem_limit: ${CITUS_MEM_LIMIT:-2048m}', (ROOT / "docker-compose-citus.yml").read_text(encoding="utf-8"))
        self.assertIn('mem_limit: ${YB_MEM_LIMIT:-3072m}', (ROOT / "docker-compose-yugabyte.yml").read_text(encoding="utf-8"))
        self.assertIn('mem_limit: ${CRDB_MEM_LIMIT:-3072m}', (ROOT / "docker-compose-cockroach.yml").read_text(encoding="utf-8"))
        for lb in ("yugabyte", "cockroach"):
            self.assertIn(f"haproxy_{lb}:", (ROOT / f"docker-compose-{lb}.yml").read_text(encoding="utf-8"))
            cfg = (ROOT / "scripts" / lb / "haproxy.cfg").read_text(encoding="utf-8")
            self.assertIn("nameserver dns 127.0.0.11:53", cfg)
            self.assertIn("init-addr last,libc,none resolvers docker", cfg)


if __name__ == "__main__":
    unittest.main()
