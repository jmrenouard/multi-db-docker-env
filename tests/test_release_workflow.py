"""Unit tests for the GitHub Actions release pipeline and release_notes helper."""

from __future__ import annotations

import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import release_notes  # noqa: E402


class TestReleasePipeline(unittest.TestCase):
    def test_resolve_tag_and_repo_sync(self) -> None:
        ver = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertEqual(release_notes.resolve_tag("", ROOT), (f"v{ver}", ver, False))
        self.assertEqual(release_notes.resolve_tag("2.3.0-rc.1", ROOT), ("v2.3.0-rc.1", "2.3.0-rc.1", True))
        with self.assertRaises(ValueError):
            release_notes.resolve_tag("invalid-tag", ROOT)
        self.assertIn(f"## Release v{ver}", release_notes.validate_version_sync(ver, ROOT))
        older = release_notes.extract_changelog_section("2.1.0", ROOT / "Changelog")
        self.assertIn("## Release v2.1.0 (2026-11-19)", older)
        self.assertNotIn("2.0.25", older)

    def test_version_drift_detection(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "cmd/mdb").mkdir(parents=True)
            (root / "VERSION").write_text("1.2.3\n", encoding="utf-8")
            (root / "cmd/mdb/main.go").write_text('var version = "1.2.3"\n', encoding="utf-8")
            (root / "Changelog").write_text("1.2.3 2026-01-01\n- feat: init\n", encoding="utf-8")
            self.assertIn("init", release_notes.validate_version_sync("1.2.3", root))
            with self.assertRaises(ValueError):
                release_notes.validate_version_sync("1.2.4", root)
            (root / "cmd/mdb/main.go").write_text('var version = "1.2.0"\n', encoding="utf-8")
            with self.assertRaises(ValueError):
                release_notes.validate_version_sync("1.2.3", root)
            (root / "cmd/mdb/main.go").write_text('var version = "1.2.3"\n', encoding="utf-8")
            (root / "Changelog").write_text("1.2.2 2026-01-01\n- fix: old\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                release_notes.validate_version_sync("1.2.3", root)

    def test_cli_and_workflow_yaml(self) -> None:
        ver = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        with tempfile.TemporaryDirectory() as tmp:
            notes, gh = pathlib.Path(tmp) / "N.md", pathlib.Path(tmp) / "gh.txt"
            self.assertEqual(release_notes.main(["--tag", f"v{ver}", "--check", "--output", str(notes), "--github-output", str(gh)]), 0)
            self.assertIn(f"## Release v{ver}", notes.read_text(encoding="utf-8"))
            self.assertIn(f"tag=v{ver}\nversion={ver}\nprerelease=false\n", gh.read_text(encoding="utf-8"))

        raw = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        for token in (
            "'v*.*.*'", "workflow_dispatch:", "contents: write", "scripts/release_notes.py",
            "python3 -m unittest discover -s tests -v", "go test -race ./...", "bash ./tests/test_config.sh",
            "linux/amd64", "linux/arm64", "darwin/amd64", "darwin/arm64", "windows/amd64", "windows/arm64",
            "-X main.version=", "SHA256SUMS.txt", "body_path: RELEASE_NOTES.md", "softprops/action-gh-release@v2",
        ):
            self.assertIn(token, raw)
        try:
            import yaml
            parsed = yaml.safe_load(raw)
            triggers = parsed.get("on") or parsed.get(True)
            self.assertIn("v*.*.*", triggers["push"]["tags"])
            self.assertIn("workflow_dispatch", triggers)
            self.assertEqual(parsed["jobs"]["release"]["needs"], "validate")
        except ImportError:
            pass


if __name__ == "__main__":
    unittest.main()
