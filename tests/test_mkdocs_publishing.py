"""Unit and E2E tests for versioned MkDocs Material docs and publishing."""

import importlib.util, json, os, re, subprocess, sys, tempfile, unittest, zipfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

try:
    import yaml
except ImportError:
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
HOOKS_PATH = ROOT / "scripts" / "mkdocs_hooks.py"
BUILD_PATH = ROOT / "scripts" / "build_versioned_docs.py"
TABS = ["Home", "Tutorials", "How-To Guides", "Reference", "Explanation", "Releases & Governance"]


def _load_mod(name, path):
    """Import script module from path."""
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class TestMkdocsPublishing(unittest.TestCase):
    """Validate mkdocs.yml, hooks, builder, security guards, and E2E."""

    def test_mkdocs_yml_and_assets(self):
        """Verify mkdocs.yml Material, Mermaid, KaTeX, mike, exclusions, assets."""
        raw = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        for pat in (r"name:\s*material", r"language:\s*en", r"provider:\s*mike", r"default:\s*latest"):
            self.assertRegex(raw, pat)
        for tok in "navigation.tabs navigation.indexes mermaid katex.min.css katex.min.js auto-render.min.js stylesheets/extra.css javascripts/katex.js scripts/mkdocs_hooks.py pymdownx.arithmatex *.kdbx *.keyx *.pem *.key *.crt .env.* ssl/ certs_patroni/".split():
            self.assertIn(tok, raw)
        for tab in TABS:
            self.assertRegex(raw, rf"(?m)^  -\s+{re.escape(tab)}:")
        if yaml is not None:
            class _L(yaml.SafeLoader):
                pass
            _L.add_multi_constructor("tag:yaml.org,2002:python/name:", lambda _l, s, _n: s)
            c = yaml.load(raw, Loader=_L)
            self.assertEqual((c["site_name"], c["edit_uri"], c["site_url"], c["repo_name"]), ("Multi-DB Docker Environment Documentation", "edit/main/docs/", "https://multi-db-docker-env.lightpath.fr/", "jmrenouard/multi-db-docker-env"))
            self.assertEqual(c["extra"]["version"], {"provider": "mike", "default": "latest"})
            self.assertIn("scripts/mkdocs_hooks.py", c["hooks"])
            self.assertEqual([next(iter(x)) for x in c["nav"]], TABS)
            sf = next(e["pymdownx.superfences"] for e in c["markdown_extensions"] if isinstance(e, dict) and "pymdownx.superfences" in e)
            self.assertTrue(any(f.get("name") == "mermaid" for f in sf["custom_fences"]))
        for rel in ("stylesheets/extra.css", "javascripts/katex.js", "assets/logo.svg", "assets/header-banner.svg"):
            p = ROOT / "docs" / rel
            self.assertTrue(p.is_file() and p.stat().st_size > 0, rel)

    def test_hooks_import_without_mkdocs_and_on_config(self):
        """Verify hooks import without mkdocs and set site_url/edit_uri."""
        blk = {"mkdocs": None, "mkdocs.structure": None, "mkdocs.structure.files": None, "pathspec": None}
        with patch.dict(sys.modules, blk):
            sys.modules.pop("_hk_iso", None)
            try:
                hk = _load_mod("_hk_iso", HOOKS_PATH)
            finally:
                sys.modules.pop("_hk_iso", None)
        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            (td / "docs").mkdir()
            (td / "docs/index.md").write_text("# H\n", encoding="utf-8")
            (td / "README.md").write_text("# R\n", encoding="utf-8")
            cfg = SimpleNamespace(site_url="https://x/", docs_dir=str(td / "docs"), mdx_configs={}, nav=[{"Home": "index.md"}, {"Drop": "gone.md"}])
            with patch.dict(os.environ, {"MDB_DOCS_SITE_URL": "https://d.ex", "MDB_DOCS_REF": "main"}):
                hk.on_config(cfg)
            self.assertEqual((cfg.site_url, cfg.edit_uri, cfg.nav), ("https://d.ex/", "edit/main/docs/", [{"Home": "index.md"}]))
            self.assertIs(cfg.mdx_configs["toc"]["slugify"], hk.gfm_slugify)
            with patch.dict(os.environ, {"MDB_DOCS_REF": "v2.6.4"}):
                hk.on_config(cfg)
            self.assertEqual(cfg.edit_uri, "")

    def test_hooks_alerts_slugs_and_prune_nav(self):
        """Verify alerts, fences, GFM slugify, and nav pruning."""
        hk = _load_mod("_hk_test", HOOKS_PATH)
        out = hk.convert_github_alerts("> [!WARNING] Watch\n> L1\n\n> [!TIP]\n> T\n\n> [!IMPORTANT]\n> I\n\n```md\n> [!NOTE]\n> F\n```\n\n> [!CAUTION]\n> Stop\n")
        for exp in ('!!! warning "Watch"\n    L1', "!!! tip\n    T", "!!! info\n    I", "!!! danger\n    Stop", "> [!NOTE]\n> F"):
            self.assertIn(exp, out)
        self.assertEqual(hk.gfm_slugify("Phase 1: Init & Check_DB <b>ok</b>"), "phase-1-init--check_db-ok")
        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            for d, f in (("docs", "index.md"), (".", "README.md"), ("documentation", "INDEX.md")):
                (td / d).mkdir(parents=True, exist_ok=True)
                (td / d / f).write_text("# X\n", encoding="utf-8")
            nav = [{"Home": "index.md"}, {"V": "overview-en.md"}, {"D": "documentation/INDEX.md"}, {"No": ["x.md"]}]
            self.assertEqual(hk.prune_nav_for_existing_files(nav, td / "docs", td), nav[:3])

    def test_hooks_rewrite_relative_links(self):
        """Verify link rewrites across depths, HTML, fallbacks, and secrets."""
        hk = _load_mod("_hk_test", HOOKS_PATH)
        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            dd = td / "docs"
            for d, f in (("docs/assets", "header-banner.svg"), ("docs/02-how-to-guides", "index.md"), ("docs/03-reference", "s.md"), ("documentation", "INDEX.md"), ("documentation", "supported_products.md")):
                (td / d).mkdir(parents=True, exist_ok=True)
                (td / d / f).write_text("x", encoding="utf-8")
            md = (
                "![L](../../../logo.png) [E](../../../README.md) [F](../../../README_fr.md) [C](../../../Changelog)\n"
                "[I](../../../documentation/INDEX.md) [R](../../03-reference/s.md) [D](../../02-how-to-guides)\n"
                "[O1](../../../docs/01-tutorials/s.md) [ExF](file:///etc/passwd) [InF](file:///x/multi-db-docker-env/docs/02-how-to-guides/index.md)\n"
                "[Env](../../../.env) [Key](../../../ca.key) [Ex](../../../.env.example)\n"
                '<img src="../../../logo.png"><a href="../../../README.md">R</a><a href="../../../s.kdbx">S</a>\n'
                "```\n[F](../.env)\n```\n`[I](../README.md)`\n"
            )
            rw = hk.rewrite_relative_links(md, "02-how-to-guides/a/b.md", "main", docs_dir=dd)
            for exp in (
                "![L](../../assets/header-banner.svg)", "[E](../../overview-en.md)", "[F](../../overview-fr.md)",
                "[C](../../CHANGELOG.md)", "[I](../../documentation/INDEX.md)", "[R](../../03-reference/s.md)",
                "[D](../../02-how-to-guides/index.md)", "[O1](../../overview-en.md)", "[InF](../../02-how-to-guides/index.md)",
                "[Ex](https://github.com/jmrenouard/multi-db-docker-env/blob/main/.env.example)",
                '<img src="../../../assets/header-banner.svg">', '<a href="../../../overview-en.md">R</a>',
                '<a href="#">S</a>', "[F](../.env)", "`[I](../README.md)`", "ExF", "Env Key",
            ):
                self.assertIn(exp, rw)
            for gone in ("file:///etc/passwd", "(.env)", "(ca.key)", "../../../.env"):
                self.assertNotIn(gone, rw)
            self.assertEqual(hk.rewrite_relative_links("![L](../../logo.png) [R](../../README.md) [G](../02-how-to-guides)", "01-tutorials/lab.md", "main", docs_dir=dd), "![L](../assets/header-banner.svg) [R](../overview-en.md) [G](../02-how-to-guides/index.md)")
            dd_h = td / "docs_h"
            dd_h.mkdir()
            self.assertEqual(hk.rewrite_relative_links("[R](03-reference/old.md) [X](m/p.md)", "index.md", "v2.3.0", docs_dir=dd_h), "[R](documentation/supported_products.md) [X](overview-en.md)")
            self.assertEqual(hk.rewrite_relative_links("[R](docs/01-tutorials/old.md)", "overview-en.md", "v2.3.0", docs_dir=dd_h), "[R](overview-en.md)")

    def test_build_versioned_docs_helpers(self):
        """Verify semver parsing, manifest, .htaccess, and redirect HTML."""
        bvd = _load_mod("_bvd_test", BUILD_PATH)
        self.assertEqual((bvd.parse_semver_tag("v2.6.4"), bvd.parse_semver_tag("2.3.0"), bvd.parse_semver_tag("v2.6")), ((2, 6, 4), (2, 3, 0), None))
        man = bvd.build_versions_manifest(["v2.3.0", "v2.6.4", "v2.4.1"])
        self.assertEqual(([e["version"] for e in man], man[0]["aliases"], man[-1]["aliases"]), (["v2.6.4", "v2.4.1", "v2.3.0", "main"], ["latest"], ["dev"]))
        self.assertEqual(bvd.build_versions_manifest([])[0]["aliases"], ["latest", "dev"])
        ht = bvd.render_htaccess("v2.6.4", enforce_https=True)
        for tok in ("RewriteCond %{HTTPS} !=on", "RewriteRule ^latest(?:/(.*))?$ /v2.6.4/$1 [R=302,L]", "X-Content-Type-Options"):
            self.assertIn(tok, ht)
        self.assertNotIn("RewriteCond %{HTTPS} !=on", bvd.render_htaccess("v2.6.4", enforce_https=False))
        rd = bvd.render_redirect_html("./v2.6.4/", 'Docs "Title"')
        for tok in ('content="0; url=./v2.6.4/"', "&quot;Title&quot;", "window.location.replace("):
            self.assertIn(tok, rd)

    def test_build_versioned_docs_security_guards(self):
        """Verify protected output guard, safe zip extract, and private check."""
        bvd = _load_mod("_bvd_test", BUILD_PATH)
        for bad in (ROOT, ROOT.parent, ROOT / "docs"):
            with self.assertRaises(ValueError):
                bvd.build_versioned_site(ROOT, bad, skip_tags=True)
        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            ok_z, bad_z = td / "ok.zip", td / "bad.zip"
            with zipfile.ZipFile(ok_z, "w") as zf:
                zf.writestr("sub/f.txt", "safe")
            with zipfile.ZipFile(bad_z, "w") as zf:
                zf.writestr("../../evil.txt", "pwn")
            bvd._safe_extract_zip(ok_z, td / "out")
            self.assertEqual((td / "out/sub/f.txt").read_text(encoding="utf-8"), "safe")
            with self.assertRaises(ValueError):
                bvd._safe_extract_zip(bad_z, td / "bad_out")
            clean = td / "clean"
            clean.mkdir()
            (clean / "index.html").write_text("<html/>", encoding="utf-8")
            bvd.assert_no_private_files(clean)
            for i, priv in enumerate((".env", ".env.prod", "vault.kdbx", "srv.key", "id_rsa")):
                pd = td / f"p{i}"
                pd.mkdir()
                (pd / priv).write_text("x", encoding="utf-8")
                with self.assertRaises(RuntimeError):
                    bvd.assert_no_private_files(pd)

    @unittest.skipIf(importlib.util.find_spec("mkdocs") is None, "mkdocs not installed")
    def test_live_versioned_mkdocs_e2e(self):
        """Run multi-version build (WORKTREE + v2.6.4 + v2.3.0) with MkDocs."""
        bvd = _load_mod("_bvd_test", BUILD_PATH)
        with tempfile.TemporaryDirectory() as tmp:
            dist = Path(tmp) / "site_dist"
            subprocess.run([sys.executable, str(BUILD_PATH), "--output", str(dist), "--main-ref", "WORKTREE", "--tags", "v2.6.4", "v2.3.0"], cwd=str(ROOT), capture_output=True, text=True, check=True)
            man = json.loads((dist / "versions.json").read_text(encoding="utf-8"))
            self.assertEqual([e["version"] for e in man], ["v2.6.4", "v2.3.0", "main"])
            for rel in ("versions.json", "index.html", ".htaccess", "latest/index.html", "dev/index.html", "main/index.html", "v2.6.4/index.html", "v2.3.0/index.html", "main/documentation/INDEX/index.html"):
                self.assertTrue((dist / rel).is_file(), rel)
            bvd.assert_no_private_files(dist)

    def test_docs_ci_and_publish_workflows(self):
        """Verify docs workflows: triggers, SHA pins, permissions, and deploy."""
        wdir = ROOT / ".github" / "workflows"
        ci_r, pb_r = [(wdir / n).read_text(encoding="utf-8") for n in ("docs-ci.yml", "docs-publish.yml")]
        sha = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$")
        for raw in (ci_r, pb_r):
            self.assertRegex(raw, r"(?m)^permissions:\s*\n\s+contents:\s*read\b")
            self.assertRegex(raw, r"(?m)^concurrency:")
            self.assertIn("timeout-minutes: 15", raw)
            uses = re.findall(r"(?m)^\s*(?:-\s*)?uses:\s*([^\s#]+)", raw)
            self.assertTrue(uses and all(sha.fullmatch(u) for u in uses))
            self.assertNotIn("secrets.", "\n".join(re.findall(r"(?m)^\s*if:\s*(.+)$", raw)))
            for m in re.finditer(r"(?m)^([ ]*)(?:-\s*)?run:([^\n]*(?:\n\1 +[^\n]*)*)", raw):
                self.assertNotIn("${{", m.group(2))
        for t in ("test_mkdocs_publishing.py", "mkdocs build --strict"):
            self.assertIn(t, ci_r)
        for t in ("https://multi-db-docker-env.lightpath.fr", "https_ready", "--enforce-https", "--no-enforce-https", "wlixcc/SFTP-Deploy-Action@", "IONOS_FTP_SERVER", "IONOS_FTP_USERNAME", "IONOS_FTP_PASSWORD", "IONOS_FTP_PORT", "IONOS_REMOTE_PATH", "local_path: ./", "local_path: .htaccess", "versions.json"):
            self.assertIn(t, pb_r)
        if yaml is not None:
            ci, pb, rl = [yaml.safe_load((wdir / n).read_text(encoding="utf-8")) for n in ("docs-ci.yml", "docs-publish.yml", "release.yml")]
            c_on, p_on = ci.get("on") or ci.get(True), pb.get("on") or pb.get(True)
            self.assertTrue({"push", "pull_request", "workflow_dispatch"} <= set(c_on))
            self.assertTrue({"push", "pull_request", "release", "workflow_run", "workflow_dispatch"} <= set(p_on))
            self.assertEqual((c_on["push"]["paths"], p_on["push"]["paths"], p_on["workflow_run"]), (c_on["pull_request"]["paths"], p_on["pull_request"]["paths"], {"workflows": [rl["name"]], "types": ["completed"]}))
            vb, dp = pb["jobs"]["verify-and-build"], pb["jobs"]["deploy-ionos"]
            self.assertEqual((dp["needs"], "pull_request" in dp["if"]), ("verify-and-build", False))
            self.assertTrue("startsWith(github.event.workflow_run.head_branch, 'v')" in vb["if"] and all(k in dp["if"] for k in ("release", "workflow_run", "refs/heads/main", "inputs.deploy == true")))
            self.assertTrue(all("${{" not in s.get("run", "") for j in [*ci["jobs"].values(), vb, dp] for s in j["steps"]))
            up = next(s["with"] for s in vb["steps"] if s.get("uses", "").startswith("actions/upload-artifact@"))
            self.assertEqual((up["name"], up["include-hidden-files"]), ("mkdocs-site-dist", True))
            sftps = [s["with"] for s in dp["steps"] if s.get("uses", "").startswith("wlixcc/SFTP-Deploy-Action@")]
            self.assertEqual([(w["local_path"], w["sftp_only"], w["remote_path"]) for w in sftps], [("./", True, "${{ secrets.IONOS_REMOTE_PATH }}/"), (".htaccess", True, "${{ secrets.IONOS_REMOTE_PATH }}/")])


if __name__ == "__main__":
    unittest.main()
