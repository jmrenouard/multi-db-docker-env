---
trigger: always_on
description: Core execution rules and constraints for the Multi-DB Docker Environment project.
category: governance
---
# 03_execution_rules.md

## 🧠 Rationale
To ensure consistency, reliability, security, and smooth code review across all database environments, orchestration scripts, and test suites. Strict adherence to these rules prevents broken tests, inconsistent naming, environment dependencies, and rejected Pull Requests.

## 🛠️ Implementation

### 1. Mandatory Testing
- Any new or modified database service, topology, or script MUST be verified locally via corresponding `make test-*` targets or test scripts before committing.
- Code must not be committed until tests pass locally.

### 2. Naming Conventions & Orchestration
- Orchestration: `Makefile` is the exclusive entry point (`make up-*`, `make down-*`, `make test-*`).
- Compose files: `docker-compose-<topology>.yml` (e.g., `docker-compose-galera.yml`, `docker-compose-patroni.yml`).
- Test scripts: `tests/test_<topology>.sh` and `tests/test_*.py`.
- Documentation: English ONLY across all technical documents, comments, issues, and PRs.

### 3. Bash & Script Portability
- All bash scripts MUST use `set -euo pipefail`.
- Variables must always be quoted (`"$VAR"`).
- Explicit error handling: no silent masking of errors or swallowed failures.

### 4. Pull Request Size & Atomic Splitting
- Maximum PR diff size is strictly **15,000 characters** (`git diff main...HEAD | wc -c` < 15000).
- Large features or cluster additions must be split into atomic, sub-15K-character Pull Requests to pass review bots (Sourcery AI limit) and human review.

## ✅ Verification
- Run `make test-config` or relevant `make test-*` targets.
- Verify bash scripts adhere to `set -euo pipefail`.
- Run `git diff main...HEAD | wc -c` to confirm PR diff size < 15,000 characters before submitting PR.
