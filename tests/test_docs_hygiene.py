"""Automated documentation hygiene, link/anchor integrity, and STE structural gate."""

from pathlib import Path
import re
import subprocess
import unittest
import unicodedata

REPO_ROOT = Path(__file__).resolve().parent.parent

# Cleaned documents enforced by structural STE checks.
MIXED_STE_DOCS = {
    "ROADMAP.md": "en",
    "documentation/INDEX.md": "en",
    "documentation/INDEX_fr.md": "fr",
    "documentation/architecture.md": "en",
}

PROCEDURAL_STE_DOCS = {
    "README.md": "en",
    "README_fr.md": "fr",
    "documentation/makefile.md": "en",
    "documentation/makefile_fr.md": "fr",
    "documentation/pg_multimaster.md": "en",
    "documentation/pg_multimaster_fr.md": "fr",
    "documentation/patroni_cluster.md": "en",
    "documentation/pgpool_cluster.md": "en",
    "documentation/galera_bootstrap.md": "en",
    "documentation/replication_setup.md": "en",
    "documentation/replication_ssl.md": "en",
    "documentation/tls_setup.md": "en",
    "documentation/scripts.md": "en",
    "documentation/tests.md": "en",
    "documentation/tests_fr.md": "fr",
    "documentation/supported_products.md": "en",
    "documentation/supported_products_fr.md": "fr",
}

EXCLUDED_LINK_DOCS = {
    "docs/ACTION_LOGBOOK.md",
    "docs/RCA_REGISTER.md",
}

EN_FORBIDDEN_RE = re.compile(
    r"\b(should|would|may|might|shall|ought|ensure|ensures|ensuring|perform|performs|performing|via)\b",
    re.I,
)
FR_FORBIDDEN_RE = re.compile(
    r"\b(devrait|devraient|pourrait|pourraient|il\s+est\s+recommand\u00e9|\u00e9ventuellement|via)\b",
    re.I,
)
EN_CONTRACTION_RE = re.compile(
    r"\b\w+n['\u2019]t\b|\b\w+['\u2019](?:re|ll|ve|m|d)\b|"
    r"\b(?:it|that|there|what|let|who|here|he|she|where|when|how)['\u2019]s\b",
    re.I,
)
_PASSIVE_PARTICIPLE = (
    r"(?:[a-z]{2,}(?:ed|en)|done|made|held|kept|sent|built|found|left|lost|"
    r"shown|known|sold|told|put|set|cut|run|broken|taken|given|written|seen|worn)"
)
EN_PASSIVE_RE = re.compile(
    rf"\b(?:(?:can|will|must|could|would|should|may|might|shall)\s+(?:not\s+)?be\s+{_PASSIVE_PARTICIPLE}\b"
    rf"|(?:is|are|was|were)\s+to\s+be\s+{_PASSIVE_PARTICIPLE}\b"
    rf"|(?:has|have|had)\s+(?:(?:not|never|already|always)\s+)?(?:[a-z]{{2,}}ed|been|done|made|gone|put|set|cut|kept|held|taken|given|found|left|lost|meant|sent|shown|told|built|become|begun|broken|brought|come|fallen|felt|got|gotten|grown|known|read|run|seen|spoken|thrown|worn|written|sold)\b"
    rf"|(?:is|are|was|were|be|been|being)\s+(?:\w+\s+)?{_PASSIVE_PARTICIPLE}\s+by\b)",
    re.I,
)
WORDISH_RE = re.compile(r"\w+(?:[.'&/\u2019-]\w+)*")


def _tracked_markdown_files():
    """Return tracked Markdown file paths relative to repository root."""
    out = subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "ls-files", "*.md"],
        text=True,
        encoding="utf-8",
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def _gfm_slug(heading):
    """Compute GitHub Flavored Markdown anchor slug for a heading string."""
    cleaned = re.sub(r"<[^>]+>", "", heading.strip())
    out = []
    for ch in cleaned.lower():
        if ch in ("-", " ") or unicodedata.category(ch).startswith(("L", "N")):
            out.append("-" if ch == " " else ch)
    return "".join(out)


def _heading_slugs(text):
    """Collect GFM anchor slugs (disambiguated on repeats) from Markdown text."""
    slugs = set()
    counts = {}
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^#{1,6}\s+(.*)$", line)
        if not m:
            continue
        base = _gfm_slug(m.group(1))
        idx = counts.get(base, 0)
        counts[base] = idx + 1
        slugs.add(base if idx == 0 else f"{base}-{idx}")
    return slugs


def _strip_code_and_html(text):
    """Remove fenced code blocks, HTML comments, and table separator rows."""
    no_fence = re.sub(r"^```.*?^```", "", text, flags=re.M | re.S)
    return re.sub(r"<!--.*?-->", "", no_fence, flags=re.S)


def _extract_prose_blocks(text):
    """Extract non-table, non-heading prose lines matching ste_check filtering."""
    body = _strip_code_and_html(text)
    body = re.sub(r"``[^`\n]+``|`[^`\n]+`", " CODE ", body)
    body = re.sub(r"!\[([^\]]*)\]\((?:[^()]|\([^)]*\))*\)", r"\1", body)
    body = re.sub(r"\[([^\]]*)\]\((?:[^()]|\([^)]*\))*\)", r"\1", body)
    body = re.sub(r"https?://\S+?(?=[.,;:!?)]*(?:\s|$))", " URL ", body)
    body = re.sub(r'"[^"\n]*"', " QUOTED ", body)
    lines = []
    for line in body.splitlines():
        s = line.strip()
        if not s or s.startswith(("#", "|", ">", "---", "<")):
            lines.append("")
            continue
        lines.append(s)
    return [b for b in "\n".join(lines).split("\n\n") if b.strip()]


def _split_sentences(block):
    """Divide a paragraph or bullet item into sentences per ste_check rules."""
    results = []
    for raw in block.splitlines():
        item = re.sub(r"^(?:[-*]|\d+\.)\s+", "", raw.strip())
        if not item:
            continue
        for sent in re.split(r"(?<=[.!?:])\s+", item):
            clean = sent.strip()
            if clean and WORDISH_RE.search(clean):
                results.append(clean)
    return results


def _count_ste_words(sentence):
    """Count STE words applying Issue 9 Rule 8.5 (parentheticals) and Rule 8.7."""
    s = sentence
    for _ in range(3):
        updated = re.sub(r"\([^()]*\)", " PAREN ", s)
        if updated == s:
            break
        s = updated
    s = re.sub(r"\*\*|__|#+|\*|(?<!\w)_|_(?!\w)", " ", s)
    return len(WORDISH_RE.findall(s))


def _makefile_targets():
    """Extract literal and PG_STACKS pattern targets defined in Makefile."""
    mk = (REPO_ROOT / "Makefile").read_text(encoding="utf-8")
    vars_map = {}
    for m in re.finditer(r"^([A-Z0-9_]+)\s*[:?]?=\s*(.+)$", mk, re.M):
        vars_map[m.group(1)] = m.group(2).split()
    targets = set(re.findall(r"^([A-Za-z0-9_.-]+)\s*:", mk, re.M))
    for m in re.finditer(r"\$\(addprefix\s+([^,]+),\$\(([A-Z0-9_]+)\)\)", mk):
        prefix, var_name = m.group(1), m.group(2)
        for item in vars_map.get(var_name, []):
            targets.add(f"{prefix}{item}")
    return targets


class TestDocsHygiene(unittest.TestCase):
    """Verify repository documentation integrity, safety blocks, and STE compliance."""

    def test_no_file_uri_links(self):
        for rel in _tracked_markdown_files():
            text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            self.assertIsNone(re.search(r"\]\(\s*file:///", text), f"Found file:/// link in {rel}")
            if rel not in EXCLUDED_LINK_DOCS:
                self.assertNotIn("file:///", text, f"Found file:/// URI in {rel}")

    def test_no_duplicate_root_rule_files(self):
        self.assertFalse((REPO_ROOT / "03_execution_rules.md").exists())
        self.assertFalse((REPO_ROOT / "04_best_practices.md").exists())
        self.assertTrue((REPO_ROOT / ".agent/rules/03_execution_rules.md").is_file())
        self.assertTrue((REPO_ROOT / ".agent/rules/04_best_practices.md").is_file())

    def test_relative_links_and_gfm_anchors_resolve(self):
        for rel in _tracked_markdown_files():
            if rel in EXCLUDED_LINK_DOCS:
                continue
            src = REPO_ROOT / rel
            text = _strip_code_and_html(src.read_text(encoding="utf-8"))
            self.assertNotIn("\ufe0f", text if rel.endswith(("INDEX.md", "INDEX_fr.md")) else "", rel)
            local_slugs = _heading_slugs(src.read_text(encoding="utf-8"))
            for m in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", text):
                link = m.group(1).strip()
                if link.startswith(("http://", "https://", "mailto:")):
                    continue
                if link.startswith("#"):
                    self.assertIn(link[1:], local_slugs, f"Broken local anchor {link} in {rel}")
                    continue
                path_part, _, frag = link.partition("#")
                target = (src.parent / path_part).resolve()
                self.assertTrue(target.exists(), f"Broken relative link {link} in {rel}")
                if frag and target.suffix.lower() == ".md":
                    target_slugs = _heading_slugs(target.read_text(encoding="utf-8"))
                    self.assertIn(frag, target_slugs, f"Broken anchor {link} in {rel}")

    def test_cited_make_targets_exist(self):
        targets = _makefile_targets()
        for rel in _tracked_markdown_files():
            if rel in EXCLUDED_LINK_DOCS:
                continue
            text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            for m in re.finditer(r"`make\s+([A-Za-z0-9_.<>*/-]+)", text):
                cmd = m.group(1)
                if any(tok in cmd for tok in ("<", ">", "*", "{", "TARGET", "SERVICE", "PROFILE")):
                    continue
                self.assertIn(cmd, targets, f"Unknown Makefile target `make {cmd}` in {rel}")

    def test_caution_blocks_near_clean_data(self):
        en_text = (REPO_ROOT / "documentation/makefile.md").read_text(encoding="utf-8")
        fr_text = (REPO_ROOT / "documentation/makefile_fr.md").read_text(encoding="utf-8")
        self.assertRegex(en_text, r"CAUTION:.*make clean-data")
        self.assertRegex(fr_text, r"ATTENTION\s*:.*make clean-data")

    def test_ste_structural_rules_on_cleaned_docs(self):
        all_docs = {**{k: (v, 25) for k, v in MIXED_STE_DOCS.items()}, **{k: (v, 20) for k, v in PROCEDURAL_STE_DOCS.items()}}
        for rel, (lang, max_words) in all_docs.items():
            raw = (REPO_ROOT / rel).read_text(encoding="utf-8")
            no_fence = _strip_code_and_html(raw)
            self.assertFalse(re.search(r"\bvia\b", no_fence, re.I), f"Found 'via' in {rel}")
            for block in _extract_prose_blocks(raw):
                forb_re = FR_FORBIDDEN_RE if lang == "fr" else EN_FORBIDDEN_RE
                m_forb = forb_re.search(block)
                self.assertIsNone(m_forb, f"Forbidden STE term in {rel}: {m_forb and m_forb.group(0)}")
                for sent in _split_sentences(block):
                    self.assertNotIn(";", sent, f"Semicolon in {rel}: {sent}")
                    if lang == "en":
                        self.assertIsNone(EN_CONTRACTION_RE.search(sent), f"Contraction in {rel}: {sent}")
                        self.assertIsNone(EN_PASSIVE_RE.search(sent), f"Passive verb form in {rel}: {sent}")
                    n_words = _count_ste_words(sent)
                    self.assertLessEqual(n_words, max_words, f"Sentence > {max_words}w ({n_words}) in {rel}: {sent}")


if __name__ == "__main__":
    unittest.main()
