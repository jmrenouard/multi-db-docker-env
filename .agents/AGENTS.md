# Workspace Rules for Multi-DB Docker Environment

> See root [`AGENTS.md`](../AGENTS.md) and `.agents/rules/` (`git-workflow.md`, `github-workflow.md`, `project-governance.md`). All project files, rules, and registers **MUST** be in **English**.

## 1. Core Architecture & PR Diff Limit

> [!IMPORTANT]
> - **Exclusive Makefile Orchestration**: All database lifecycle actions, setups, benchmarks, and tests run via `Makefile`.
> - **Strict PR Diff Limit (`< 15,000` chars)**: Run `git diff main...HEAD | wc -c` before opening any PR. Split larger changes into atomic PRs.

## 2. Mandatory Systematic 9-Step GitHub Workflow

For **every modification** (code, configuration, scripts, CI/CD, refactoring, documentation):
0. **GitHub Issue (`gh issue create`)**: Open an issue via `gh issue create` (strictly in English).
1. **Dedicated Branch**: Create `<type>/issue-<id>-<slug>` from `main` (or `git worktree`).
2. **Implementation, Registers & Validation Tests**:
   - Update [`docs/ACTION_LOGBOOK.md`](../docs/ACTION_LOGBOOK.md) and [`docs/RCA_REGISTER.md`](../docs/RCA_REGISTER.md) on every request, change, and result.
   - All code, shell, Makefile, and SQL comments MUST be strictly in English.
   - Synchronize `VERSION`, `Changelog`, `ROADMAP.md`, and `POTENTIAL_ISSUES.md` when code/topology changes; run test suite.
3. **Rigorous Staging (`git add`)**: Stage only tracked files via `git add`.
4. **Structured Commit (`git commit`)**: Atomic Conventional Commits in English referencing issue, keeping diff `< 15,000` chars.
5. **Branch Push (`git push`)**: Push branch to remote: `git push -u origin <branch>`.
6. **Pull Request (`gh pr create`)**: Open PR via `gh pr create` in English targeting `main`.
7. **PR Merge (`gh pr merge`)**: Merge via `gh pr merge --merge --delete-branch` with English merge commit message, sync `main`.
8. **Issue Closure (`gh issue close`)**: Close the issue with an explicit completion comment in English (`gh issue comment <id> --body "..."` followed by `gh issue close <id>`).

## 3. Mandatory English-Only Policy

All GitHub issues, PRs, PR merge commit messages, issue closing comments, commit messages, and source code comments (Python, Bash, SQL, Makefiles) MUST be strictly in English. Zero French is permitted on GitHub or in code comments.
