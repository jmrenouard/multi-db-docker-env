"""Build a multi-version MkDocs Material site bundle for IONOS Apache hosting."""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess  # nosec B404
import sys
import tempfile
import zipfile
from pathlib import Path

_SEMVER_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")
_SAFE_REF_RE = re.compile(r"^[A-Za-z0-9._/\-]+$")
_PRIVATE_RE = re.compile(r"(?i)(?:^|/)(?:\.env[^/]*|id_rsa[^/]*)$|\.(?:kdbx|keyx|pem|key)$")
_PROTECTED = (".git", ".github", ".agent", ".agents", "docs", "documentation", "scripts", "tests", "pkg", "cmd", "conf", "initdb")

ALWAYS_OVERLAY_FILES: tuple[str, ...] = ("mkdocs.yml", "scripts/mkdocs_hooks.py", "docs/stylesheets/extra.css", "docs/javascripts/katex.js")
FALLBACK_OVERLAY_FILES: tuple[str, ...] = ("docs/index.md", "docs/assets/logo.svg", "docs/assets/header-banner.svg")


def parse_semver_tag(tag: str) -> tuple[int, int, int] | None:
    """Parse semver Git tag like `v2.6.4` into `(major, minor, patch)`."""
    return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if (m := _SEMVER_RE.fullmatch(tag.strip())) else None


def _sort_tags_descending(tags: list[str]) -> list[str]:
    """Sort unique tags newest-first by semver, non-semver last."""
    uniq = list(dict.fromkeys(t.strip() for t in tags if t.strip()))
    return sorted(uniq, key=lambda t: (1, p, t) if (p := parse_semver_tag(t)) else (0, (0, 0, 0), t), reverse=True)


def discover_release_tags(repo_root: Path, min_version: tuple[int, int, int] | str = (2, 3, 0), max_tags: int = 15) -> list[str]:
    """Discover semver Git tags >= `min_version` sorted newest-first up to `max_tags`."""
    min_v = min_version if isinstance(min_version, tuple) else parse_semver_tag(str(min_version))
    if min_v is None:
        raise ValueError(f"Invalid min_version: {min_version!r}")
    out = subprocess.run(["git", "-C", str(repo_root), "tag", "--list"], capture_output=True, text=True, check=True).stdout  # nosec B603, B607
    valid = [t for ln in out.splitlines() if (p := parse_semver_tag(t := ln.strip())) is not None and p >= min_v]
    ordered = _sort_tags_descending(valid)
    return ordered[:max_tags] if max_tags > 0 else ordered


def build_versions_manifest(release_tags: list[str], include_main: bool = True) -> list[dict[str, object]]:
    """Build Material (`provider: mike`) `versions.json` entries newest-first."""
    tags = _sort_tags_descending(release_tags)
    entries: list[dict[str, object]] = [{"version": t, "title": t, "aliases": ["latest"] if i == 0 else []} for i, t in enumerate(tags)]
    if include_main:
        entries.append({"version": "main", "title": "main (dev)", "aliases": ["dev"] if tags else ["latest", "dev"]})
    return entries


def render_redirect_html(target_url: str, title: str = "Multi-DB Docker Environment Documentation") -> str:
    """Render minimal HTML redirect page for static hosting."""
    eu, et, ju = html.escape(target_url, quote=True), html.escape(title, quote=True), json.dumps(target_url)
    return (
        f'<!DOCTYPE html>\n<html lang="en">\n<head>\n  <meta charset="utf-8">\n  <title>{et}</title>\n'
        f'  <meta http-equiv="refresh" content="0; url={eu}">\n  <link rel="canonical" href="{eu}">\n'
        f'  <script>window.location.replace({ju});</script>\n</head>\n<body>\n'
        f'  <p>Redirecting to <a href="{eu}">{eu}</a>...</p>\n</body>\n</html>\n'
    )


def render_htaccess(latest_version: str, main_version: str = "main", enforce_https: bool = True) -> str:
    """Render Apache `.htaccess` with security headers and version rewrites."""
    lat, mv = latest_version.strip("/"), main_version.strip("/")
    https = "  RewriteCond %{HTTPS} !=on\n  RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]\n  RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]\n\n" if enforce_https else ""
    return (
        f"# Multi-DB Versioned Docs\nOptions -Indexes -MultiViews\nDirectoryIndex index.html\nErrorDocument 404 /{lat}/404.html\n\n"
        "<IfModule mod_deflate.c>\n  AddOutputFilterByType DEFLATE text/html text/plain text/css text/xml application/javascript application/json image/svg+xml\n</IfModule>\n\n"
        "<IfModule mod_headers.c>\n  Header always set X-Content-Type-Options \"nosniff\"\n"
        "  Header always set Referrer-Policy \"strict-origin-when-cross-origin\"\n"
        "  Header always set Permissions-Policy \"geolocation=(), microphone=(), camera=()\"\n"
        "  Header always set X-Frame-Options \"SAMEORIGIN\"\n"
        "  <FilesMatch \"versions\\.json$\">\n    Header set Cache-Control \"public, max-age=300, must-revalidate\"\n  </FilesMatch>\n</IfModule>\n\n"
        f"<IfModule mod_rewrite.c>\n  RewriteEngine On\n  RewriteBase /\n{https}"
        f"  RewriteRule ^$ /{lat}/ [R=302,L]\n  RewriteRule ^latest(?:/(.*))?$ /{lat}/$1 [R=302,L]\n  RewriteRule ^dev(?:/(.*))?$ /{mv}/$1 [R=302,L]\n</IfModule>\n"
    )


def _validate_git_ref(git_ref: str) -> str:
    """Validate Git ref cannot be interpreted as a CLI flag."""
    cleaned = git_ref.strip()
    if not cleaned or cleaned.startswith("-") or not _SAFE_REF_RE.fullmatch(cleaned):
        raise ValueError(f"Invalid git ref: {git_ref!r}")
    return cleaned


def _safe_extract_zip(archive_path: Path, dest_dir: Path) -> None:
    """Extract ZIP archive into `dest_dir` with path traversal protection."""
    root = dest_dir.resolve()
    with zipfile.ZipFile(archive_path, "r") as zf:
        for info in zf.infolist():
            member = (root / info.filename).resolve()
            if not member.is_relative_to(root):
                raise ValueError(f"Unsafe archive member path: {info.filename!r}")
            if info.is_dir():
                member.mkdir(parents=True, exist_ok=True)
            else:
                member.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(info, "r") as src_f, open(member, "wb") as dst_f:
                    shutil.copyfileobj(src_f, dst_f)


def _overlay_repo_files(repo_root: Path, snapshot_dir: Path) -> None:
    """Overlay current MkDocs config, hooks, theme assets, and fallback files."""
    specs = [(r, True) for r in ALWAYS_OVERLAY_FILES] + [(r, False) for r in FALLBACK_OVERLAY_FILES]
    for rel, overwrite in specs:
        src, dst = repo_root / rel, snapshot_dir / rel
        if src.is_file() and (overwrite or not dst.is_file()):
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


def assert_no_private_files(output_dir: Path) -> None:
    """Verify zero `.env*`, vault, key, or SSH private files exist in `output_dir`."""
    bad = [p.relative_to(output_dir).as_posix() for p in output_dir.rglob("*") if p.is_file() and _PRIVATE_RE.search(p.relative_to(output_dir).as_posix())]
    if bad:
        raise RuntimeError(f"Privacy violation in built output ({output_dir}): {bad}")


def _run_mkdocs_build(project_dir: Path, site_out: Path, git_ref: str, slug: str, base_url: str, strict: bool) -> None:
    """Invoke `python -m mkdocs build` for one version directory."""
    env = {**os.environ, "PYTHONUTF8": "1", "MDB_DOCS_REF": "main" if git_ref in {"WORKTREE", "origin/main", "main", "HEAD"} else git_ref, "MDB_DOCS_SITE_URL": f"{base_url.rstrip('/')}/{slug}/"}
    cmd = [sys.executable, "-m", "mkdocs", "build", "-f", str(project_dir / "mkdocs.yml"), "-d", str(site_out), *(["--strict"] if strict else [])]
    subprocess.run(cmd, cwd=str(project_dir), env=env, check=True)  # nosec B603


def build_single_version(repo_root: Path, git_ref: str, version_slug: str, output_dir: Path, base_url: str, strict: bool = True) -> Path:
    """Build one version (`WORKTREE` or `git archive` snapshot)."""
    ref = _validate_git_ref(git_ref)
    ver_out = output_dir / version_slug
    ver_out.parent.mkdir(parents=True, exist_ok=True)
    if ref == "WORKTREE":
        _run_mkdocs_build(repo_root, ver_out, ref, version_slug, base_url, strict)
    else:
        with tempfile.TemporaryDirectory(prefix=f"mdb-docs-{version_slug}-") as tmp:
            tp = Path(tmp)
            arc, snap = tp / "snapshot.zip", tp / "src"
            snap.mkdir(parents=True, exist_ok=True)
            subprocess.run(["git", "-C", str(repo_root), "archive", "--format=zip", "-o", str(arc), ref], check=True)  # nosec B603, B607
            _safe_extract_zip(arc, snap)
            _overlay_repo_files(repo_root, snap)
            _run_mkdocs_build(snap, ver_out, ref, version_slug, base_url, strict)
    assert_no_private_files(ver_out)
    return ver_out


def build_versioned_site(repo_root: Path, output_dir: Path, base_url: str = "https://multi-db-docker-env.lightpath.fr", main_ref: str = "WORKTREE", tags: list[str] | None = None, min_version: tuple[int, int, int] | str = (2, 3, 0), max_tags: int = 15, skip_tags: bool = False, strict: bool = True, enforce_https: bool = True) -> dict[str, object]:
    """Build full multi-version site bundle with redirects, `.htaccess`, and `versions.json`."""
    r_repo, r_out = repo_root.resolve(), output_dir.resolve()
    protected = {r_repo / name for name in _PROTECTED}
    if r_out == r_repo or r_repo.is_relative_to(r_out) or any(r_out == p or r_out.is_relative_to(p) for p in protected):
        raise ValueError(f"Output directory must not overwrite repository or protected paths: {r_out}")
    if r_out.exists():
        shutil.rmtree(r_out)
    r_out.mkdir(parents=True, exist_ok=True)

    rel_tags = [] if skip_tags else (_sort_tags_descending(tags) if tags is not None else discover_release_tags(r_repo, min_version=min_version, max_tags=max_tags))
    manifest = build_versions_manifest(rel_tags, include_main=True)
    (r_out / "versions.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    for slug, ref in [("main", main_ref), *[(t, t) for t in rel_tags]]:
        build_single_version(r_repo, ref, slug, r_out, base_url, strict)

    lat = rel_tags[0] if rel_tags else "main"
    bt = "Multi-DB Docker Environment Documentation"
    (r_out / ".htaccess").write_text(render_htaccess(lat, "main", enforce_https=enforce_https), encoding="utf-8")
    for sub, tgt, ttl in ((".", f"./{lat}/", bt), ("latest", f"../{lat}/", f"{bt} ({lat})"), ("dev", "../main/", f"{bt} (main / dev)")):
        d = r_out / sub
        d.mkdir(parents=True, exist_ok=True)
        (d / "index.html").write_text(render_redirect_html(tgt, ttl), encoding="utf-8")

    assert_no_private_files(r_out)
    return {"output_dir": str(r_out), "latest_version": lat, "versions": [e["version"] for e in manifest]}


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse CLI args for versioned documentation build."""
    p = argparse.ArgumentParser(description="Build versioned Multi-DB docs.")
    for flag, kw in (
        ("--output", {"default": "site_dist"}),
        ("--base-url", {"default": "https://multi-db-docker-env.lightpath.fr"}),
        ("--main-ref", {"default": "WORKTREE"}),
        ("--tags", {"nargs": "*", "default": None}),
        ("--min-version", {"default": "2.3.0"}),
        ("--max-tags", {"type": int, "default": 15}),
        ("--skip-tags", {"action": "store_true"}),
        ("--no-strict", {"action": "store_true"}),
        ("--enforce-https", {"action": argparse.BooleanOptionalAction, "default": True}),
        ("--repo-root", {"default": str(Path(__file__).resolve().parents[1])}),
    ):
        p.add_argument(flag, **kw)
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint for versioned MkDocs Material site generation."""
    a = _parse_args(argv)
    tags = [i.strip() for raw in a.tags for i in raw.split(",") if i.strip()] if a.tags is not None else None
    summary = build_versioned_site(Path(a.repo_root), Path(a.output), a.base_url, a.main_ref, tags, a.min_version, a.max_tags, a.skip_tags, not a.no_strict, a.enforce_https)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
