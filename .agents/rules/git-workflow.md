---
description: Mandatory Git and GitHub workflow (Issue -> Branch -> Pull Request -> Merge) for every request in the Multi-DB Docker Environment project.
trigger: always_on
---

# Project Rule: Systematic Issue + Branch + Pull Request + Merge

For every user request on this project, you **MUST MANDATORILY** execute the complete GitHub workflow in English:

1. **Create a GitHub Issue** with `gh issue create --title "..." --body "..."`.
2. **Create a dedicated branch** from `main`: `git checkout -b <type>/issue-<number>-<slug>` (use `git worktree` if uncommitted changes exist in the workspace).
3. **Implement and test** all changes with test targets and keep PR diff `< 15,000` characters (`git diff main...HEAD | wc -c`).
4. **Update Governance Registers** (`docs/ACTION_LOGBOOK.md` and `docs/RCA_REGISTER.md`) before committing.
5. **Commit and push** the branch (`git push -u origin <branch>`) referencing `Closes #<number>`.
6. **Create a Pull Request** with `gh pr create --base main --head <branch> --title "..." --body "Closes #<number>..."`.
7. **Merge the Pull Request** with `gh pr merge --merge --delete-branch` and sync `main`.
8. **Close the Issue with a Comment**: Post a completion comment on the GitHub Issue detailing the changes, verification results, and merge commit (`gh issue comment <number> --body "..."`), then close the issue (`gh issue close <number>`).
