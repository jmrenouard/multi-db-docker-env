# RCA Register — Errors, Technical Dead-Ends, Approximations & Unimplemented Ideas

> **Governance Rule ([`AGENTS.md`](../AGENTS.md) §4 & [`.agents/rules/project-governance.md`](../.agents/rules/project-governance.md))**:
> This register guarantees full engineering traceability for the **Multi-DB Docker Environment** project. It **MUST be systematically updated on every request, every change, and every result** across its four sections:
> 1. **Errors & Bugs Encountered (Root Cause Analysis — RCA)**
> 2. **Technical Dead-Ends & Abandoned Leads (`IMP`)**
> 3. **Current Approximations & Simplifying Assumptions (`APP`)**
> 4. **Unimplemented Ideas & Future Roadmap (`IDEA`)**

---

## 1. Errors & Bugs Encountered (Root Cause Analysis — RCA)

### RCA-001 — Permission Denied on Directory Cleanup via Makefile (`make clean-galera`, `make clean-repli`)
- **Date / Linked Action**: `2026-08-01` (`POTENTIAL_ISSUES.md` item 1)
- **Observed Symptom**: `rm -rf datadir_*` failed with `Permission denied` when executed on the host without `sudo`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did cleanup fail?* Files inside `datadir_*` are generated and owned by `root` (or container `mysql`/`postgres` UID) inside Docker.
  2. *Why does the host user lack access?* Host user is non-root without direct write access to root-owned files.
  3. *Why not require `sudo`?* Requiring `sudo` breaks automated CI pipelines and unprivileged development workstations.
- **Applied Change / Fix**: Wrapped cleanup operations in a lightweight alpine container runner (`docker run --rm -v $(PWD):/work alpine rm -rf /work/datadir_*`).
- **Result & Non-Regression Test**: `make clean-galera` and `make clean-repli` execute cleanly without root permission errors.

### RCA-002 — Subprocess `FileNotFoundError` on Host when Database CLI Binaries are Absent
- **Date / Linked Action**: `2026-10-30` (`ACT-001`)
- **Observed Symptom**: Running `unittest` on Windows hosts without local `mysql` or `psql` clients in PATH crashed with `FileNotFoundError: [WinError 2]`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did tests crash?* `tests/test_lab.py` called `subprocess.run(["mysql", ...])` unconditionally.
  2. *Why was `mysql` absent?* Workstations running Docker often do not install native database client binaries on the host OS.
  3. *Why did other test scripts not crash?* Shell tests run inside bash or test container scripts.
- **Applied Change / Fix**: Handled `FileNotFoundError` defensively in `run_mysql_query()` and `run_pg_query()` returning a safe failed `CompletedProcess`, allowing tests to skip gracefully when clients are missing.
- **Result & Non-Regression Test**: `python -m unittest discover -s tests -v` runs without unhandled process exceptions.

---

## 2. Technical Dead-Ends & Abandoned Leads (`IMP`)

### IMP-001 — Monolithic Pull Requests Exceeding 15,000 Diff Characters
- **Why It Is a Dead-End**: Automated review bots (Sourcery AI) and CI review gates reject or fail on oversized PRs (`> 15,000` diff characters).
- **Adopted Decision**: Enforce strict `< 15,000` diff character limit (`git diff main...HEAD | wc -c`) via sequential atomic Pull Requests.

### IMP-002 — Hardcoding Credentials and Personal Access Tokens in Scripts
- **Why It Is a Dead-End**: Embedding credentials in compose files or scripts (e.g. `scripts/fix_issue.sh`) triggers security alerts (Sourcery AI PR #24-#26) and risks credential leakage.
- **Adopted Decision**: All credentials must be sourced from `.env` or explicit environment variables (`GITHUB_TOKEN`, `DB_ROOT_PASSWORD`).

### IMP-003 — Permissive File Permissions on SSL/TLS Certificates (`chmod 666` / `777`)
- **Why It Is a Dead-End**: Permissive private key permissions violate database security requirements (PostgreSQL refuses keys with loose permissions).
- **Adopted Decision**: Restrict TLS private key permissions strictly to `600` and directories to `755`.

---

## 3. Current Approximations & Simplifying Assumptions (`APP`)

### APP-001 — Standard Default Passwords for Isolated Laboratory Testing
- **Target Files**: `.env`, `docker-compose*.yml`
- **Nature & Justification**: Local development and PoC tests use standard passwords (`DB_ROOT_PASSWORD=votre_mot_de_passe_super_secret`) for reproducibility.
- **Removal Condition**: Production deployments must inject strong, dynamically generated secrets from a secrets manager (Vault, AWS Secrets Manager, etc.).

### APP-002 — Single-Port Routing via Traefik Reverse Proxy (`3306` / `5432`)
- **Target Files**: `docker-compose.yml`, Traefik configuration
- **Nature & Justification**: Traefik routes port `3306` to the currently active database service for transparent client switching. Only one active MySQL/MariaDB service should bind to port 3306 at a given time.
- **Removal Condition**: Dedicated port ranges used when multiple disparate topologies must run concurrently.

---

## 4. Unimplemented Ideas & Future Roadmap (`IDEA`)

### IDEA-001 — ClickHouse and Redis Standalone and Cluster Topologies
- **Priority / Target**: `Medium` · `docker-compose-clickhouse.yml`, `docker-compose-redis.yml`
- **Description**: Add lightweight Compose definitions and Makefile targets for columnar analytics (ClickHouse) and in-memory caching (Redis).

### IDEA-002 — Automated Network Partitioning / Chaos Resilience Tests
- **Priority / Target**: `High` · `tests/test_chaos.sh`
- **Description**: Use Toxiproxy or `tc netem` to simulate network lag and split-brain scenarios in Galera, Patroni, and InnoDB Cluster topologies.

### IDEA-003 — Automated Pre-Commit PR Diff Character Count Gate
- **Priority / Target**: `Medium` · `.githooks/pre-commit`
- **Description**: Git hook rejecting commits that exceed 15,000 diff characters relative to `main` without explicit bypass.
