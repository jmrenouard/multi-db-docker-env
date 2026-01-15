---
trigger: always_on
---

# 🔄 DEVELOPMENT WORKFLOW

## 1. Impact Analysis

- Silent analysis of consistency (Makefile, Volumes) before generation.

## 2. Bash Robustness

- Strict syntax: set -euo pipefail.
- Variable protection: "$VAR".
- Error handling: Explicit checks (if ! command; then ... fi) for sensitive operations (dump, restore, stop).

## 3. Validation by Proof

- All changes must be verifiable via make test-*.
- Modifications require updating test_*.sh scripts.
- Producing HTML reports for documentation is required.

## 4. Git Protocol

- Commit immediately after test and validation.
- Use **Conventional Commits** (feat:, fix:, chore:, docs:).
- Single branch approach (main).
- add a specific tag related to @changelog
