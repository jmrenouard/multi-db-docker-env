"""Diataxis 4-quadrant, ASD-STE100 Issue 9, and Docs-as-Code test suite."""

import configparser, json, re, shutil, subprocess, tempfile, unittest
from pathlib import Path
from urllib.parse import unquote

try:
    import yaml
except ImportError:
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
PORTAL = "https://multi-db-docker-env.lightpath.fr"
TUT, HOW, REF, EXP = QUADS = ("01-tutorials", "02-how-to-guides", "03-reference", "04-explanation")
TABS = ["Home", "Tutorials", "How-To Guides", "Reference", "Explanation", "Releases & Governance"]
VIRTUAL = {"overview-en.md": "README.md", "overview-fr.md": "README_fr.md", "CHANGELOG.md": "Changelog"}
EXCLUDED = frozenset({"docs/ACTION_LOGBOOK.md", "docs/RCA_REGISTER.md"})
SENT_RE = re.compile(r"(?<!No\.)(?<!e\.g\.)(?<!i\.e\.)(?<!etc\.)(?<=[.!?:])\s+")
WORD_RE = re.compile(r"[A-Za-z0-9]+(?:[.'&/’-][A-Za-z0-9]+)*")
ING_OK = frozenset("mating missing remaining lighting opening routing servicing something during ring spring string nothing anything everything".split())
NON_PP = frozenset("between even exceed feed hundred need often open proceed red screen seed speed succeed sudden when".split())
_PP = r"(?:[a-z]{2,}(?:ed|en)|been|done|made|gone|put|set|cut|kept|held|taken|given|found|left|lost|sent|shown|told|built|broken|written|read|run)"
STE_RULES = (
    ("GR-6", re.compile(r"(?<![A-Za-z])(?:e\.g\.|i\.e\.|etc\.)(?![A-Za-z])", re.I), 0),
    ("Rule 3.2", re.compile(r"\b(?:should|would|may|might|shall|ought)\b", re.I), 0),
    ("Rule 4.2", re.compile(r"\b\w+n['’]t\b|\b\w+['’](?:re|ll|ve|m|d)\b|\b(?:it|that|there|what|let|who|here|he|she|where|when|how)['’]s\b", re.I), 0),
    ("Rule 3.4", re.compile(rf"\b(?:(?:has|have|had)\s+(?:(?:not|never|already|always)\s+)?|(?:(?:can|will|must|could|would|should|may|might|shall)\s+(?:not\s+)?be|(?:is|are|was|were)\s+to\s+be)\s+){_PP}\b", re.I), 1),
    ("Rule 3.6", re.compile(rf"\b(?:is|are|was|were|be|been|being)\s+(?:\w+\s+)?{_PP}\s+by\b", re.I), 1),
    ("Rule 3.5", re.compile(r"\b(?:is|are|was|were|be|been|am)\s+[a-z]+ing\b", re.I), 1),
)
_STRIP = (
    (r"\A---\n.*?\n---(?:\n|\Z)|```.*?```|~~~.*?~~~", " ", re.S),
    (r"(?<!\\)\$\$.*?(?<!\\)\$\$|(?<!\\)\$(?!\s)(?:[^\n$\\]|\\.)+?(?<!\s)\$", " MATH ", re.S),
    (r"``[^`\n]+``|`[^`\n]+`|https?://\S+?(?=[.,;:!?)]*(?:\s|$))|\"[^\"\n]*\"|“[^”\n]*”|«[^»\n]*»", " TOK ", 0),
    (r"!?\[([^\]]*)\]\((?:[^()]|\([^)]*\))*\)", r"\1", 0),
    (r"(?m)^[ \t]*(?:>|#|\||---+|\*\*\*+|___+|===+).*$", "", 0),
)


def _extract_nav(raw):
    """Extract nav tabs and Markdown paths without PyYAML."""
    blk = m.group(1) if (m := re.search(r"(?m)^nav:\s*\n((?:[ \t#].*(?:\n|\Z)|\n)*)", raw)) else ""
    return re.findall(r"(?m)^  -\s+([^:]+):", blk), re.findall(r"([A-Za-z0-9_./-]+\.md)\b", blk)


def _docs_in(q):
    """Return sorted non-index Markdown files in quadrant."""
    return sorted(p for p in (DOCS / q).rglob("*.md") if p.name.lower() != "index.md")


def _non_code(text):
    """Return non-fenced `(lineno, line)` pairs."""
    out, ch, ln = [], None, 0
    for idx, raw in enumerate(text.splitlines(), 1):
        if ch:
            if re.match(rf"^\s*{re.escape(ch)}{{{ln},}}\s*$", raw):
                ch, ln = None, 0
        elif m := re.match(r"^\s*(`{3,}|~{3,})", raw):
            ch, ln = m.group(1)[0], len(m.group(1))
        else:
            out.append((idx, re.sub(r"``[^`\n]+``|`[^`\n]+`", " ", raw)))
    return out


def _rel_links(md):
    """Return `(lineno, target, resolved_path)` for relative links."""
    res = []
    for ln, line in _non_code(md.read_text(encoding="utf-8")):
        for raw in re.findall(r"!?\[[^\]]*\]\(([^)\n]+)\)", line):
            t = re.sub(r"^<([^>]+)>.*|(\S+).*", r"\1\2", raw.strip())
            if t and not t.startswith(("#", "//")) and not re.match(r"^(?:https?|mailto|ftp|tel|data):", t, re.I):
                if c := unquote(t.split("#", 1)[0].split("?", 1)[0].strip()):
                    res.append((ln, c, (DOCS / c.lstrip("/") if c.startswith("/") else md.parent / c).resolve()))
    return res


def _check_sent(sent, loc):
    """Check one sentence for STE structural violations."""
    errs = []
    clean = re.sub(r"\*\*|__|(?<!\w)_|_(?!\w)|\*", "", sent)
    s = re.sub(r"\([^()]*\)", " P ", re.sub(r"\([^()]*\)", " P ", clean))
    if (wc := len(WORD_RE.findall(s))) > 20:
        errs.append(f"{loc} [Rule 5.1]: {wc}w")
    if ";" in sent:
        errs.append(f"{loc} [Rule 8.1]: ;")
    for tag, pat, ign in STE_RULES:
        if m := pat.search(clean):
            w = m.group(0).split()
            p = (w[-2] if tag == "Rule 3.6" and len(w) >= 2 else w[-1]).lower()
            if not ign or (p not in NON_PP and (tag != "Rule 3.5" or p not in ING_OK)):
                errs.append(f"{loc} [{tag}]: {m.group(0)!r}")
    return errs


def ste_violations(md):
    """Collect ASD-STE100 structural violations for one Markdown file."""
    txt = md.read_text(encoding="utf-8").replace("\r\n", "\n")
    for pat, rep, fl in _STRIP:
        txt = re.sub(pat, rep, txt, flags=fl)
    bre = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
    rel = md.relative_to(ROOT).as_posix() if md.is_relative_to(ROOT) else md.name
    errs = []
    for idx, par in enumerate(re.split(r"\n\s*\n", txt), 1):
        if not WORD_RE.search(par):
            continue
        lns = re.sub(r"\n(?:  |\t)(?=\S)", " ", par.strip()).splitlines()
        prose = [ln for ln in lns if not bre.match(ln)]
        grps = [(f"{rel}:list", [bre.sub("", ln, 1) for ln in lns if bre.match(ln)], 0)]
        if prose:
            grps.append((f"{rel}:par{idx}", ["\n".join(prose)], 6))
        for loc, chunks, cap in grps:
            sents = [s.strip() for c in chunks for s in SENT_RE.split(c) if WORD_RE.search(s)]
            if cap and len(sents) > cap:
                errs.append(f"{loc} [Rule 6.6]: {len(sents)}s")
            for s in sents:
                errs.extend(_check_sent(s, loc))
    return errs


class TestDiataxisDocumentation(unittest.TestCase):
    """Validate Diataxis structure, links, STE, and Docs-as-Code."""

    def test_quadrant_structure(self):
        """Verify portal, quadrants, indexes, and docs exist."""
        self.assertTrue((DOCS / "index.md").is_file())
        for q in QUADS:
            self.assertTrue((DOCS / q / "index.md").is_file() and _docs_in(q), q)

    def test_relative_links_resolve(self):
        """Verify relative links in docs resolve on disk."""
        broken = [
            f"{md.relative_to(ROOT).as_posix()}:{ln}: {tgt}"
            for md in sorted(DOCS.rglob("*.md")) if md.relative_to(ROOT).as_posix() not in EXCLUDED
            for ln, tgt, r in _rel_links(md) if not (r.is_file() or (r / "index.md").is_file())
        ]
        self.assertEqual(broken, [], "\n".join(broken))

    def test_quadrant_genre_guardrails(self):
        """Verify quadrant genre boundaries are enforced."""
        forb_h = {HOW: r"\b(?:why|architecture|theory|explanation|context|background)\b", EXP: r"\b(?:step\s+\d+|rollback|remediation|prerequisites|procedure)\b"}
        errs = []
        for q in QUADS[1:]:
            for md in _docs_in(q):
                rel, nc = md.relative_to(ROOT).as_posix(), _non_code(md.read_text(encoding="utf-8"))
                body = "\n".join(l for _, l in nc)
                if q in forb_h:
                    errs.extend(f"{rel}:{ln}" for ln, l in nc if l.startswith("#") and re.search(forb_h[q], l, re.I))
                if q == HOW:
                    errs.extend(f"{rel}: no {k}" for k, p in (("verif", r"\b(?:validat\w+|verif\w+|check)\b"), ("rollback", r"\b(?:rollback|revert|back-?out|undo)\b")) if not re.search(p, body, re.I))
                elif q == REF:
                    if not any(re.match(r"^\s*(?:\|.*\||(?:[-*+]|\d+\.)\s+\S)", l) for _, l in nc):
                        errs.append(f"{rel}: no table")
                    errs.extend(f"{rel}:{ln}" for ln, l in nc if re.search(r"\b(?:in\s+this\s+tutorial|let['’]?s|let\s+us|step\s+1)\b", l, re.I))
        self.assertEqual(errs, [], "\n".join(errs))

    def test_cross_linking_mesh(self):
        """Verify tutorials, guides, alert matrix, and ADRs cross-link."""
        qof = lambda md: {r.relative_to(DOCS).parts[0] for _, _, r in _rel_links(md) if r.is_relative_to(DOCS) and r.relative_to(DOCS).parts[0] in QUADS}
        mesh = (
            (_docs_in(TUT), {HOW, REF, EXP}), (_docs_in(HOW), {REF, EXP}),
            (sorted((DOCS / EXP / "design-decisions").glob("adr-*.md")), {HOW, REF}),
            ([DOCS / REF / "troubleshooting-codes/error-and-alert-matrix.md"], {HOW}),
        )
        for grp, req in mesh:
            self.assertTrue(grp)
            for d in grp:
                self.assertTrue(d.is_file() and req <= qof(d), d)

    def test_howto_ste_compliance(self):
        """Verify how-to guides pass ASD-STE100 checks."""
        files = _docs_in(HOW)
        self.assertTrue(files)
        self.assertEqual([v for md in files for v in ste_violations(md)], [])

    def test_ste_checker_unit(self):
        """Verify STE checker accepts valid prose and catches errors."""
        with tempfile.TemporaryDirectory() as tmp:
            ok, bad = Path(tmp) / "ok.md", Path(tmp) / "bad.md"
            ok.write_text("# Run\n\n1. Stop it.\n2. Check log.\n\nOutput is zero.\n", encoding="utf-8")
            self.assertEqual(ste_violations(ok), [])
            bad.write_text("# Bad\n\n1. You should stop; don't wait.\n2. It was cleaned by the job after one full minute of quiet polling on each active database node inside local storage.\n", encoding="utf-8")
            out = "\n".join(ste_violations(bad))
            for r in ("3.2", "8.1", "4.2", "3.6", "5.1"):
                self.assertIn(f"[Rule {r}]", out)

    def test_docs_as_code_configs(self):
        """Verify mkdocs.yml, .vale.ini, and .markdownlint.json."""
        mk = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        tabs, paths = _extract_nav(mk)
        self.assertEqual(tabs, TABS)
        for tok in ("navigation.tabs", "navigation.indexes", "scripts/mkdocs_hooks.py"):
            self.assertIn(tok, mk)
        if yaml is not None:
            cfg = _load_mkdocs_yaml(ROOT / "mkdocs.yml")
            self.assertEqual([next(iter(e)) for e in cfg["nav"]], TABS)
            self.assertTrue({"navigation.tabs", "navigation.indexes"} <= set(cfg["theme"]["features"]))
            self.assertIn("scripts/mkdocs_hooks.py", cfg["hooks"])
        for np in paths:
            self.assertTrue((ROOT / VIRTUAL[np] if np in VIRTUAL else (ROOT / np if np.startswith("documentation/") else DOCS / np)).is_file(), np)

        cp = configparser.ConfigParser()
        cp.optionxform = str
        cp.read_string("[r]\n" + (ROOT / ".vale.ini").read_text(encoding="utf-8"))
        self.assertEqual((cp["r"]["StylesPath"], cp[f"docs/{HOW}/**/*.md"]["MinAlertLevel"]), (".vale/styles", "error"))
        for s in ("*.md", *(f"docs/{q}/**/*.md" for q in (TUT, REF, EXP))):
            self.assertIn(s, cp)
        lint = json.loads((ROOT / ".markdownlint.json").read_text(encoding="utf-8"))
        self.assertTrue(lint.get("default") and lint["MD013"]["line_length"] == 120 and lint["MD033"] is False)

    def test_portal_and_readmes(self):
        """Verify portal and READMEs expose all quadrants."""
        portal = (DOCS / "index.md").read_text(encoding="utf-8")
        for tok in (*[f"{q}/index.md" for q in QUADS], "ACTION_LOGBOOK.md", "RCA_REGISTER.md", PORTAL):
            self.assertIn(tok, portal)
        for name in ("README.md", "README_fr.md"):
            txt = (ROOT / name).read_text(encoding="utf-8")
            self.assertTrue("docs/index.md" in txt and PORTAL in txt and all(f"docs/{q}/index.md" in txt for q in QUADS))


def _load_mkdocs_yaml(path):
    """Load a MkDocs YAML config with Python-tag safe constructor."""
    class _Loader(yaml.SafeLoader):
        pass
    _Loader.add_multi_constructor("tag:yaml.org,2002:python/name:", lambda _l, s, _n: s)
    return yaml.load(path.read_text(encoding="utf-8"), Loader=_Loader)


def _iter_fenced_blocks(text):
    """Yield `(indent, tag, body, lineno)` for fenced code blocks."""
    lines, i, n = text.splitlines(), 0, len(text.splitlines())
    while i < n:
        if m := re.match(r"^([ \t]*)(`{3,}|~{3,})([^\r\n]*)$", lines[i]):
            ind, ch, fl, tag, start = m.group(1), m.group(2)[0], len(m.group(2)), m.group(3).strip(), i + 1
            j = i + 1
            while j < n and not (lines[j].strip().startswith(ch) and len(lines[j].strip()) >= fl and not lines[j].strip().strip(ch).strip()):
                j += 1
            yield ind, tag, "\n".join(lines[i + 1:j]), start
            i = j + 1
            continue
        i += 1


class TestDocsExecutableAndI18n(unittest.TestCase):
    """Verify FR/EN isolation, STF100, Mermaid hygiene, and executable docs."""

    _FR_BANNED = re.compile(r"\b(?:devrait|devraient|pourrait|pourraient|il\s+faut|vous\s+devez|vous\s+pouvez)\b", re.I)
    _FR_GERUND = re.compile(r"\ben\s+[a-zàâçéèêëîïôûùüÿœ]+ant\b", re.I)
    _FR_PASSIVE = re.compile(r"\b(?:est|sont|était|étaient|sera|seront|été)\s+[a-zàâçéèêëîïôûùüÿœ]{3,}(?:é|ée|és|ées|is|it|its|tes)\s+par\b", re.I)
    _MM_HDR = re.compile(r"^(?:flowchart|graph|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|gantt|pie|gitGraph|journey|mindmap|timeline|quadrantChart|requirementDiagram|C4Context|xychart-beta|block-beta)\b")

    def test_fr_diataxis_stf_and_i18n_isolation(self):
        """Verify FR Diataxis structure, STF100 rules, and EN/FR MkDocs isolation."""
        for rel in ("docs/index_fr.md", "docs/01-tutoriels/index.md", "docs/02-guides-pratiques/index.md", "docs/04-explications/index.md"):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertGreaterEqual(len(_docs_in("01-tutoriels")), 3)
        fr_how = _docs_in("02-guides-pratiques")
        self.assertGreaterEqual(len(fr_how), 4)
        errs = []
        for md in fr_how:
            raw = md.read_text(encoding="utf-8")
            rel = md.relative_to(ROOT).as_posix()
            for req in ("## Prérequis", "## Procédure", "## Vérification", "## Retour arrière", "> [!CAUTION]"):
                if req not in raw:
                    errs.append(f"{rel}: missing {req}")
            txt = raw.replace("\r\n", "\n")
            for pat, rep, fl in _STRIP:
                txt = re.sub(pat, rep, txt, flags=fl)
            for s in [c.strip() for c in SENT_RE.split(txt) if WORD_RE.search(c)]:
                if len(re.findall(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9]+", s)) > 20:
                    errs.append(f"{rel}: >20w: {s[:60]}")
                for lbl, pat in ((";", re.compile(r";")), ("modal", self._FR_BANNED), ("gerund", self._FR_GERUND), ("passive", self._FR_PASSIVE)):
                    if m := pat.search(s):
                        errs.append(f"{rel}: {lbl}: {m.group(0)!r}")
        self.assertEqual(errs, [], "\n".join(errs))

        en_raw, fr_raw = (ROOT / "mkdocs.yml").read_text(encoding="utf-8"), (ROOT / "mkdocs.fr.yml").read_text(encoding="utf-8")
        self.assertNotRegex(en_raw.split("\nnav:", 1)[1], r"(?:_fr\.md|overview-fr|01-tutoriels|02-guides-pratiques|04-explications)")
        self.assertNotRegex(fr_raw.split("\nnav:", 1)[1], r"(?:_en\.md|overview-en|01-tutorials|02-how-to-guides|03-reference|04-explanation)")
        for tok in ("01-tutoriels/", "02-guides-pratiques/", "04-explications/", "index_fr.md"):
            self.assertIn(tok, en_raw.split("exclude_docs:", 1)[1].split("\nnav:", 1)[0])
        for tok in ("01-tutoriels/", "02-guides-pratiques/", "04-explications/"):
            self.assertIn(tok, fr_raw.split("\nnav:", 1)[1])
        if yaml is not None:
            en_c, fr_c = _load_mkdocs_yaml(ROOT / "mkdocs.yml"), _load_mkdocs_yaml(ROOT / "mkdocs.fr.yml")
            self.assertEqual((en_c["theme"]["language"], fr_c["theme"]["language"]), ("en", "fr"))
            self.assertEqual(({x["lang"] for x in en_c["extra"]["alternate"]}, {x["lang"] for x in fr_c["extra"]["alternate"]}), ({"en", "fr"}, {"en", "fr"}))

    def test_zero_ascii_diagrams_and_valid_mermaid(self):
        """Verify zero ASCII box diagrams and valid column-0 Mermaid blocks across docs."""
        skip = {".git", "_site", "site", "node_modules", ".venv"}
        errs = []
        for md in sorted(ROOT.rglob("*.md")):
            if any(p in skip or p.startswith("_site") for p in md.relative_to(ROOT).parts):
                continue
            rel, raw = md.relative_to(ROOT).as_posix(), md.read_text(encoding="utf-8")
            for ln, line in _non_code(raw):
                if re.search(r"[┌┐└┘╔╗╚╝═║]", line):
                    errs.append(f"{rel}:{ln}: unicode box diagram outside mermaid")
            for ind, tag, body, ln in _iter_fenced_blocks(raw):
                hdr = next((l.strip() for l in body.splitlines() if l.strip() and not l.strip().startswith("%%")), "")
                if tag.split()[0].lower() == "mermaid" if tag else False:
                    if ind:
                        errs.append(f"{rel}:{ln}: indented mermaid fence")
                    if not self._MM_HDR.match(hdr):
                        errs.append(f"{rel}:{ln}: invalid mermaid header {hdr!r}")
                    if m := re.search(r"\|[^|\"\n]*[()][^|\"\n]*\|", body):
                        errs.append(f"{rel}:{ln}: unquoted parens in edge label {m.group(0)!r}")
                else:
                    if self._MM_HDR.match(hdr) and not tag:
                        errs.append(f"{rel}:{ln}: untagged mermaid block")
                    if re.search(r"[┌┐╔╗╚╝═║]", body) or (re.search(r"\+[-]{3,}\+", body) and re.search(r"(?:-->|\|)", body)):
                        errs.append(f"{rel}:{ln}: ASCII box diagram in code block")
        self.assertEqual(errs, [], "\n".join(errs))

    def test_tutorials_and_howtos_executable_verification(self):
        """Verify cited Compose files, scripts, Make targets, and CLI subcommands exist and pass dry checks."""
        doc_files = [p for q in ("01-tutorials", "02-how-to-guides", "01-tutoriels", "02-guides-pratiques") for p in (DOCS / q).rglob("*.md")]
        full_txt = "\n".join(f.read_text(encoding="utf-8") for f in doc_files)
        blocks = "\n".join(body for _, _, body, _ in _iter_fenced_blocks(full_txt))
        composes = sorted(set(re.findall(r"\b(docker-compose[A-Za-z0-9_.-]*\.yml)\b", full_txt)))
        scripts = sorted(set(re.findall(r"\b((?:scripts|tests)/[A-Za-z0-9_./-]+\.sh)\b", full_txt)))
        targets = sorted(set(re.findall(r"(?m)(?:^|[;&|]\s*)make\s+([a-zA-Z0-9_-]+)\b", blocks)))
        subcmds = sorted(set(re.findall(r"\./mdb\s+([a-z0-9_-]+)\b", blocks)))
        self.assertTrue(composes and scripts and targets and subcmds)

        for rel in composes + scripts:
            self.assertTrue((ROOT / rel).is_file(), f"Missing cited file: {rel}")
        if yaml is not None:
            for rel in composes:
                data = yaml.safe_load((ROOT / rel).read_text(encoding="utf-8"))
                self.assertIsInstance(data.get("services"), dict, rel)
        mk_targets = set(re.findall(r"(?m)^([a-zA-Z0-9_-]+):", (ROOT / "Makefile").read_text(encoding="utf-8")))
        self.assertEqual(sorted(t for t in targets if t not in mk_targets), [])
        mdb_src = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "cmd/mdb").glob("*.go"))
        for sc in subcmds:
            self.assertIn(f'"{sc}"', mdb_src, f"Unknown ./mdb subcommand: {sc}")

        self.assertIn("/etc/patroni.yml", (ROOT / "conf/supervisord-patroni.conf").read_text(encoding="utf-8"))
        for p in (DOCS / "01-tutorials/03-postgres-multimaster-lab.md", DOCS / "01-tutoriels/03-lab-postgres-multimaster.md"):
            txt = p.read_text(encoding="utf-8")
            self.assertLess(txt.index("./mdb down pg18-birep"), txt.index("./mdb bench pg18-birep"), p.name)
        if shutil.which("bash"):
            res = subprocess.run(["bash", "-c", 'rc=0; for f in "$@"; do bash -n "$f" || rc=1; done; exit $rc', "_", *scripts], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr)
        if shutil.which("make"):
            for tgt in targets:
                res = subprocess.run(["make", "-n", tgt], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, f"make -n {tgt}: {res.stderr}")
        if shutil.which("go"):
            res = subprocess.run(["go", "run", "./cmd/mdb", "--help"], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr)
            cat = subprocess.run(["go", "run", "./cmd/mdb", "catalog", "--json"], cwd=ROOT, capture_output=True, text=True, check=True)
            ids = {e["id"] for e in json.loads(cat.stdout)}
            self.assertTrue({"mysql84", "mariadb114", "patroni", "pg18-birep", "postgres18"} <= ids)


if __name__ == "__main__":
    unittest.main()
