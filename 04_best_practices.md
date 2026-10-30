---
trigger: always_on
description: Best practices for coding, testing, container management, and security in the Multi-DB Docker Environment project.
category: governance
---
# 04_best_practices.md

## 🧠 Rationale
To maintain high code quality, standardized output formatting, clean container lifecycle, and safe execution across all supported database engines and clusters.

## 🛠️ Implementation

### 1. Automated vs. Manual Checks
- Prioritize automated, reproducible test targets (`make test-*`) over ad-hoc manual commands.
- Ensure robust error handling and timeout guards for all database readiness and replication wait loops.

### 2. Clean Container Lifecycle & Idempotency
- Ensure clean startup and shutdown via `make stop` or `make <topology>-down`.
- Database volumes and certificates must be handled idempotently without permission lockouts (`root`-owned file removal via Docker alpine helper).

### 3. Security (Lab & Production Guidelines)
- While default passwords (e.g. `DB_ROOT_PASSWORD` in `.env`) are accepted for local laboratory testing, production configurations must enforce decoupled, secret-managed credentials.
- NEVER hardcode secrets or Personal Access Tokens (PAT) directly in repository files or scripts.
- Restrict TLS private key permissions to `600` and certificates directories to `755`.

### 4. Continuous Quality & Bot Review Compliance
- Code changes must adhere to Sourcery AI and static analysis standards.
- Maintain `ROADMAP.md` and `POTENTIAL_ISSUES.md` in sync whenever structural, configuration, or security changes are introduced.

## ✅ Verification
- Run automated security/config checks (`make test-config`).
- Verify no secrets or credentials leaked in git status or diff.
