"""MkDocs Material hooks for Multi-DB Docker Environment."""

from __future__ import annotations

import os
import posixpath
import re
import unicodedata
from pathlib import Path
from typing import Any, Iterable

DEFAULT_REPO_URL = "https://github.com/jmrenouard/multi-db-docker-env"
VIRTUAL_DOCS = {"overview-en.md": ("README.md", ""), "overview-fr.md": ("README_fr.md", ""), "CHANGELOG.md": ("Changelog", "")}
_REPO_TO_VIRTUAL = {s: u for u, (s, _) in VIRTUAL_DOCS.items()}
QUADRANT_HISTORICAL_FALLBACKS = {"01-tutorials": "overview-en.md", "02-how-to-guides": "documentation/INDEX.md", "03-reference": "documentation/supported_products.md", "04-explanation": "documentation/architecture.md"}
ALERT_MAP = {"NOTE": "note", "TIP": "tip", "IMPORTANT": "info", "WARNING": "warning", "CAUTION": "danger"}
_FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})")
_ALERT_RE = re.compile(r"(?m)^([ \t]*)>[ \t]*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*([^\r\n]*)\r?\n((?:[ \t]*>.*(?:\r?\n|$))*)")
_QUOTE_PFX_RE = re.compile(r"^[ \t]*>[ \t]?")
_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")
_EXCLUDED_RE = re.compile(r"(?i)(?:^|/)(?:\.env(?!\.example$)(?:\.[^/]+)?|id_rsa(?:\.[^/]+)?)$|\.(?:kdbx|keyx|pem|key|crt)$")
_HTML_ATTR_RE = re.compile(r"""(<(?:img|a|source)\b[^>]*?\b(?:src|href)\s*=\s*)(["'])([^"']+)\2""", re.I)


def gfm_slugify(value: str, separator: str = "-") -> str:
    """Slugify heading using GFM anchor rules."""
    clean = re.sub(r"<[^>]+>", "", value.strip()).lower()
    return "".join(separator if c == " " else c for c in clean if c in (" ", "-", "_") or unicodedata.category(c).startswith(("L", "N")))


def _ref(raw: str | None = None) -> str:
    r = (raw if raw is not None else os.environ.get("MDB_DOCS_REF", "main")).strip()
    return "main" if not r or r in {"WORKTREE", "HEAD", "origin/main"} else r


def _fences(md: str) -> list[tuple[bool, str]]:
    out, buf, fc, fl = [], [], "", 0
    for ln in md.splitlines(True):
        st = ln.strip()
        if not fc and (m := _FENCE_RE.match(ln)):
            if buf:
                out.append((False, "".join(buf)))
                buf.clear()
            fc, fl = m.group(1)[0], len(m.group(1))
        elif fc and st.startswith(fc) and len(st) >= fl and not st.strip(fc).strip():
            out.append((True, "".join(buf) + ln))
            buf.clear()
            fc = ""
            continue
        buf.append(ln)
    return out + ([(bool(fc), "".join(buf))] if buf else [])


def convert_github_alerts(markdown: str) -> str:
    """Convert GitHub alerts to Material admonitions."""
    def _fmt(m: re.Match[str]) -> str:
        ws, k, t = m.group(1), ALERT_MAP[m.group(2).upper()], m.group(3).strip()
        lines = [_QUOTE_PFX_RE.sub("", ln) if ln.strip().lstrip(">").strip() else None for ln in m.group(4).splitlines()]
        body = "".join(f"{ws}    {ln}\n" if ln is not None else "\n" for ln in lines)
        return (f'{ws}!!! {k} "{t}"\n' if t else f"{ws}!!! {k}\n") + body
    return "".join(c if f else _ALERT_RE.sub(_fmt, c) for f, c in _fences(markdown))


def _code_end(t: str, i: int) -> int | None:
    j = i + 1
    while j < len(t) and t[j] == "`":
        j += 1
    return None if (e := t.find(t[i:j], j)) == -1 else e + j - i


def _delim(t: str, s: int, op: str, cl: str, code: bool) -> int | None:
    d, i, n = 1, s + 1, len(t)
    while i < n:
        c = t[i]
        if c == "\\" and i + 1 < n and t[i + 1] != "\n":
            i += 2
        elif code and c == "`":
            if (i := _code_end(t, i)) is None:
                return None
        elif c == "\n" and (not code or (i + 1 < n and t[i + 1] == "\n")):
            return None
        else:
            if c == op:
                d += 1
            elif c == cl and (d := d - 1) == 0:
                return i
            i += 1
    return None


def _resolve(url: str, src: str, pfx: str, ref: str, repo_url: str, rdocs: frozenset[str], dd: Path | None) -> tuple[str | None, bool]:
    if url.lower().startswith("file:"):
        if "/multi-db-docker-env/" not in url:
            return None, True
        url, src = url.split("/multi-db-docker-env/", 1)[1].lstrip("/"), ""
    if not url or url.startswith(("#", "/", "\\")) or _SCHEME_RE.match(url):
        return url, False
    pt, sep, frag = url.partition("#")
    an = f"{sep}{frag}" if sep else ""
    norm = src.replace("\\", "/").lstrip("/")
    sdir = "" if not norm or norm in VIRTUAL_DOCS else posixpath.dirname(norm if norm.startswith("documentation/") else f"docs/{norm}")
    sl = pt.endswith("/")
    rel = posixpath.normpath(posixpath.join(sdir, pt)) if sdir else posixpath.normpath(pt)
    if _EXCLUDED_RE.search(rel) or _EXCLUDED_RE.search(pt):
        return None, True

    repo, root = repo_url.rstrip("/"), (dd.parent if dd else None)
    virt = lambda u, s, a="": f"{pfx}{u}{a}" if u in rdocs else f"{repo}/blob/{ref}/{s}{a}"
    ov = virt("overview-en.md", "README.md")
    tl = "/" if sl and not rel.endswith("/") else ""

    if rel == "logo.png":
        return (f"{pfx}assets/header-banner.svg{an}" if not dd or (dd / "assets/header-banner.svg").is_file() else f"{repo}/blob/{ref}/logo.png"), False
    if rel in _REPO_TO_VIRTUAL:
        return virt(_REPO_TO_VIRTUAL[rel], rel, an), False
    if rel.startswith("docs/"):
        sub = rel[5:]
        if sub in VIRTUAL_DOCS and (not dd or not (dd / sub).is_file()):
            return virt(sub, VIRTUAL_DOCS[sub][0], an), False
        if dd:
            top = sub.split("/", 1)[0]
            if (fb := QUADRANT_HISTORICAL_FALLBACKS.get(top)) and not (dd / top).is_dir():
                return (f"{pfx}{fb}" if (dd / fb).is_file() or (root and (root / fb).is_file()) or fb in rdocs else ov), False
            if norm == "index.md" and not (dd / "01-tutorials").is_dir() and not (dd / sub).exists() and sub not in rdocs:
                return ov, False
            if (dd / sub / "index.md").is_file():
                return f"{pfx}{sub.rstrip('/')}/index.md{an}", False
        return f"{pfx}{sub}{tl}{an}", False
    if rel.startswith("documentation/"):
        if not root or (root / rel).is_file():
            return f"{pfx}{rel}{an}", False
        return (f"{pfx}documentation/INDEX.md" if (root / "documentation/INDEX.md").is_file() else ov), False
    if rel in (".", "..") or rel.startswith("../"):
        return repo, False
    return f"{repo}/{'tree' if sl or (root and (root / rel).is_dir()) else 'blob'}/{ref}/{rel}{tl}{an}", False


def _rw(t: str, html_fn: Any, res_fn: Any) -> str:
    out, ps, i, n = [], 0, 0, len(t)
    while i < n:
        c = t[i]
        if c == "\\" and i + 1 < n:
            i += 2
            continue
        if c == "`":
            if i > ps:
                out.append(html_fn(t[ps:i]))
            if (ce := _code_end(t, i)) is None:
                return "".join(out) + t[i:]
            out.append(t[i:ce])
            i = ps = ce
            continue
        img = c == "!" and i + 1 < n and t[i + 1] == "["
        bs = i + 1 if img else (i if c == "[" else -1)
        if bs == -1 or (be := _delim(t, bs, "[", "]", True)) is None or be + 1 >= n or t[be + 1] != "(" or (pe := _delim(t, be + 1, "(", ")", False)) is None:
            i += 1
            continue
        if i > ps:
            out.append(html_fn(t[ps:i]))
        lbl, rd = _rw(t[bs + 1:be], html_fn, res_fn), t[be + 2:pe].strip()
        ang = rd.startswith("<") and (ae := rd.find(">")) != -1
        url, ts = (rd[1:ae].strip(), rd[ae + 1:]) if ang else ((rd[:m.start()], rd[m.start():]) if (m := re.search(r"\s", rd)) else (rd, ""))
        r, neut = res_fn(url)
        img_pfx, target = ("!" if img else ""), (f"<{r}>" if ang else r)
        out.append(("" if img else lbl) if neut else f"{img_pfx}[{lbl}]({target}{ts})")
        i = ps = pe + 1
    return "".join(out) + (html_fn(t[ps:n]) if n > ps else "")


def rewrite_relative_links(markdown: str, page_src_path: str, ref: str = "main", repo_url: str = DEFAULT_REPO_URL, docs_dir: Path | None = None, use_directory_urls: bool = True, available_root_docs: Iterable[str] | None = None) -> str:
    """Rewrite repository-relative Markdown and HTML links."""
    norm = page_src_path.replace("\\", "/").lstrip("/")
    md_d = norm.count("/")
    hp = "../" * (md_d + (0 if not use_directory_urls or norm == "index.md" or norm.endswith("/index.md") else 1))
    mp, rf, dd = "../" * md_d, _ref(ref), (Path(docs_dir) if docs_dir else None)
    rdocs = frozenset(VIRTUAL_DOCS) if available_root_docs is None else frozenset(available_root_docs)
    res_fn = lambda u, p=mp: _resolve(u, norm, p, rf, repo_url, rdocs, dd)
    html_fn = lambda s: _HTML_ATTR_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}{'#' if (r := res_fn(m.group(3), hp))[1] else r[0]}{m.group(2)}", s)
    return "".join(c if f else _rw(c, html_fn, res_fn) for f, c in _fences(markdown))


def prune_nav_for_existing_files(nav: list[Any] | None, docs_dir: Path, repo_root: Path) -> list[Any]:
    """Prune missing pages and empty nav sections."""
    ex = lambda r: (docs_dir / r).is_file() or (r in VIRTUAL_DOCS and (repo_root / VIRTUAL_DOCS[r][0]).is_file()) or (r.startswith("documentation/") and (repo_root / r).is_file())

    def _p(it: Any) -> Any:
        if isinstance(it, str):
            return it if ex(it) else None
        if isinstance(it, list):
            return [x for y in it if (x := _p(y)) is not None]
        if isinstance(it, dict):
            return {k: x for k, v in it.items() if (x := _p(v))} or None
        return None
    return _p(list(nav)) or [] if nav else []


def on_config(config: Any) -> Any:
    """Configure site_url, edit_uri, GFM slugifier, and pruned nav."""
    if url := os.environ.get("MDB_DOCS_SITE_URL", "").strip():
        config.site_url = url.rstrip("/") + "/"
    config.edit_uri = "edit/main/docs/" if _ref() == "main" else ""
    if isinstance(mdx := getattr(config, "mdx_configs", None), dict) and isinstance(toc := mdx.setdefault("toc", {}), dict) and not toc.get("slugify"):
        toc["slugify"] = gfm_slugify
    if getattr(config, "nav", None):
        config.nav = prune_nav_for_existing_files(config.nav, d := Path(config.docs_dir), d.parent)
    return config


def on_files(files: Any, config: Any) -> Any:
    """Exclude private files and inject virtual docs and guides."""
    from mkdocs.structure.files import File, Files, InclusionLevel

    kept = []
    for f in list(files):
        if _EXCLUDED_RE.search(f.src_uri):
            f.inclusion = InclusionLevel.EXCLUDED
        else:
            kept.append(f)
    if len(kept) != len(files):
        files = Files(kept)
    root = Path(config.docs_dir).parent
    for uri, (rel, _) in VIRTUAL_DOCS.items():
        if (p := root / rel).is_file() and files.get_file_from_path(uri) is None:
            kw = {"content": r if (r := p.read_text(encoding="utf-8")).lstrip().startswith("# ") else f"# Changelog\n\n{r}"} if uri == "CHANGELOG.md" else {"abs_src_path": str(p)}
            files.append(File.generated(config, uri, **kw))
    for p in sorted((root / "documentation").glob("*.md")):
        if p.is_file() and files.get_file_from_path(u := f"documentation/{p.name}") is None:
            files.append(File.generated(config, u, abs_src_path=str(p)))
    return files


def on_page_markdown(markdown: str, page: Any, config: Any, files: Any) -> str:
    """Convert alerts, rewrite links, and adjust virtual edit URLs."""
    src = getattr(page.file, "src_uri", None) or str(page.file.src_path).replace("\\", "/")
    rf, repo = _ref(), (getattr(config, "repo_url", None) or DEFAULT_REPO_URL).rstrip("/")
    dd = Path(rd) if (rd := getattr(config, "docs_dir", None) or (config.get("docs_dir") if isinstance(config, dict) else None)) else None
    if ed := VIRTUAL_DOCS[src][0] if src in VIRTUAL_DOCS else (src if src.startswith("documentation/") and dd and (dd.parent / src).is_file() else None):
        page.edit_url = f"{repo}/edit/main/{ed}" if rf == "main" else None
    avail = [k for k in VIRTUAL_DOCS if files.get_file_from_path(k) is not None] if files is not None else None
    return rewrite_relative_links(convert_github_alerts(markdown), src, rf, repo, dd, bool(getattr(config, "use_directory_urls", True)), avail)
