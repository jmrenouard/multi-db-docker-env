"""Unit tests verifying the project governance rules, Action Logbook, and RCA Register."""

from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class TestProjectGovernanceRules(unittest.TestCase):
    """Validate English project governance rules, Action Logbook, and RCA Register."""

    def test_governance_rules_inscribed_in_agents_and_rules_dir(self) -> None:
        """Verify AGENTS.md and .agents/rules/*.md enforce Logbook, RCA, and GitHub workflow in English."""
        agents_md = ROOT / "AGENTS.md"
        workspace_agents_md = ROOT / ".agents" / "AGENTS.md"
        gov_rule_md = ROOT / ".agents" / "rules" / "project-governance.md"
        git_rule_md = ROOT / ".agents" / "rules" / "git-workflow.md"
        gh_rule_md = ROOT / ".agents" / "rules" / "github-workflow.md"
        exec_rule_md = ROOT / "03_execution_rules.md"
        bp_rule_md = ROOT / "04_best_practices.md"

        self.assertTrue(agents_md.is_file(), "AGENTS.md must exist at repository root")
        self.assertTrue(workspace_agents_md.is_file(), ".agents/AGENTS.md must exist")
        self.assertTrue(gov_rule_md.is_file(), ".agents/rules/project-governance.md must exist")
        self.assertTrue(git_rule_md.is_file(), ".agents/rules/git-workflow.md must exist")
        self.assertTrue(gh_rule_md.is_file(), ".agents/rules/github-workflow.md must exist")
        self.assertTrue(exec_rule_md.is_file(), "03_execution_rules.md must exist at root")
        self.assertTrue(bp_rule_md.is_file(), "04_best_practices.md must exist at root")

        agents_content = agents_md.read_text(encoding="utf-8")
        gov_content = gov_rule_md.read_text(encoding="utf-8")
        git_content = git_rule_md.read_text(encoding="utf-8")
        gh_content = gh_rule_md.read_text(encoding="utf-8")
        exec_content = exec_rule_md.read_text(encoding="utf-8")
        bp_content = bp_rule_md.read_text(encoding="utf-8")

        self.assertIn("trigger: always_on", gov_content)
        self.assertIn("trigger: always_on", git_content)
        self.assertIn("trigger: always_on", gh_content)
        self.assertIn("trigger: always_on", exec_content)
        self.assertIn("trigger: always_on", bp_content)

        for content in (agents_content, gov_content):
            self.assertIn("docs/ACTION_LOGBOOK.md", content)
            self.assertIn("docs/RCA_REGISTER.md", content)
            self.assertIn("every request", content.lower())
            self.assertIn("every change", content.lower())
            self.assertIn("every result", content.lower())

        for content in (agents_content, git_content, gh_content):
            self.assertIn("gh issue comment", content)
            self.assertIn("gh issue close", content)

    def test_action_logbook_exists_in_english_and_tracks_ongoing_and_completed_actions(self) -> None:
        """Verify docs/ACTION_LOGBOOK.md exists in English and contains structured ongoing/completed sections."""
        logbook_path = ROOT / "docs" / "ACTION_LOGBOOK.md"
        self.assertTrue(logbook_path.is_file(), "docs/ACTION_LOGBOOK.md must exist")

        content = logbook_path.read_text(encoding="utf-8")
        self.assertIn("Ongoing Actions", content)
        self.assertIn("Completed Actions", content)
        self.assertIn("Request", content)
        self.assertIn("Changes", content)
        self.assertIn("Result", content)

    def test_rca_register_exists_in_english_and_covers_all_four_mandatory_categories(self) -> None:
        """Verify docs/RCA_REGISTER.md covers Errors (RCA), Dead-Ends, Approximations, and Unimplemented Ideas."""
        rca_path = ROOT / "docs" / "RCA_REGISTER.md"
        self.assertTrue(rca_path.is_file(), "docs/RCA_REGISTER.md must exist")

        content = rca_path.read_text(encoding="utf-8")
        self.assertIn("Errors & Bugs Encountered", content)
        self.assertIn("RCA", content)
        self.assertIn("Technical Dead-Ends", content)
        self.assertIn("Current Approximations", content)
        self.assertIn("Unimplemented Ideas", content)

        self.assertIn("RCA-001", content)
        self.assertIn("IMP-001", content)
        self.assertIn("APP-001", content)
        self.assertIn("IDEA-001", content)

    def test_roadmap_and_potential_issues_consolidated_in_english(self) -> None:
        """Verify ROADMAP.md and POTENTIAL_ISSUES.md redirect to living registers and enforce English."""
        roadmap_path = ROOT / "ROADMAP.md"
        potential_issues_path = ROOT / "POTENTIAL_ISSUES.md"
        logbook_path = ROOT / "docs" / "ACTION_LOGBOOK.md"
        agents_path = ROOT / "AGENTS.md"

        self.assertTrue(roadmap_path.is_file(), "ROADMAP.md must exist as redirection pointer")
        self.assertTrue(potential_issues_path.is_file(), "POTENTIAL_ISSUES.md must exist as redirection pointer")

        roadmap_content = roadmap_path.read_text(encoding="utf-8")
        potential_issues_content = potential_issues_path.read_text(encoding="utf-8")
        logbook_content = logbook_path.read_text(encoding="utf-8")
        agents_content = agents_path.read_text(encoding="utf-8")

        self.assertIn("docs/ACTION_LOGBOOK.md", roadmap_content)
        self.assertIn("docs/RCA_REGISTER.md", potential_issues_content)
        self.assertIn("Strategic Roadmap & Milestones", logbook_content)
        self.assertIn("English", agents_content)

    def test_all_bash_scripts_have_set_euo_pipefail(self) -> None:
        """Verify that every bash script in scripts/ and tests/ declares set -euo pipefail."""
        scripts_dir = ROOT / "scripts"
        tests_dir = ROOT / "tests"

        sh_files = [
            p
            for p in list(scripts_dir.rglob("*.sh")) + list(tests_dir.rglob("*.sh"))
            if p.resolve() != (tests_dir / "lib" / "common.sh").resolve()
        ]
        self.assertTrue(len(sh_files) > 0, "Expected non-empty list of shell scripts")

        missing = []
        for sh_path in sh_files:
            content = sh_path.read_text(encoding="utf-8")
            if "set -euo pipefail" not in content:
                missing.append(str(sh_path.relative_to(ROOT)))

        self.assertEqual(
            missing,
            [],
            f"The following bash scripts do not declare 'set -euo pipefail': {missing}",
        )

    def test_no_french_table_headers_remain(self) -> None:
        """Verify that no French table headers, UI labels, comments, or accented text remain in scripts/ or tests/."""
        import re

        targets = [
            p for p in (list((ROOT / "scripts").rglob("*.sh")) + list((ROOT / "tests").rglob("*.sh")))
            if p.is_file()
        ]

        french_accent_pattern = re.compile(r"[éèêëàâçîïôûùÉÈÊËÀÂÇÎÏÔÛÙ]")
        banned_patterns = re.compile(
            r"\b("
            r"nature du test|résultat réel|resultat reel|génération de l.autorité|generation de l.autorite|"
            r"attendu|arrêt du conteneur|arret du conteneur|serveur|serveurs|"
            r"explorateur de configuration|rechercher une variable|composants filtr[eé]s|"
            r"deltas mesur[eé]s|retard maximal|esclaves|"
            r"charger les variables|fichier de config|fichier pem|certificats pour|"
            r"construction des arguments|construction de la commande|démarrage du service|demarrage du service|"
            r"exécution d.etcd|execution d.etcd|sans par d[eé]faut|fusionner avec|"
            r"identifiants par d[eé]faut|pour [eé]viter|latence haProxy|latence directe|"
            r"rapport de performance|audit de performance"
            r")\b",
            re.IGNORECASE,
        )

        violations = []
        for p in targets:
            rel = p.relative_to(ROOT)
            content = p.read_text(encoding="utf-8", errors="replace")
            for i, line in enumerate(content.splitlines(), 1):
                if french_accent_pattern.search(line) or banned_patterns.search(line):
                    violations.append(f"{rel}:{i}: {line.strip()[:80]}")

        self.assertEqual(
            violations,
            [],
            f"Residual French strings found in scripts/ or tests/ ({len(violations)} violations):\n"
            + "\n".join(violations),
        )


if __name__ == "__main__":
    unittest.main()
