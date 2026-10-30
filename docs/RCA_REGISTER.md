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
- **Date / Linked Action**: `2026-08-01` (PR #31)
- **Observed Symptom**: `rm -rf datadir_*` failed with `Permission denied` when executed on the host without `sudo`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did cleanup fail?* Files inside `datadir_*` are generated and owned by `root` (or container `mysql`/`postgres` UID) inside Docker.
  2. *Why does the host user lack access?* Host user is non-root without direct write access to root-owned files.
  3. *Why not require `sudo`?* Requiring `sudo` breaks automated CI pipelines and unprivileged workstations.
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

### RCA-003 — Root Password Mismatch in Galera & Replication Scripts (`init-permissions.sql`)
- **Date / Linked Action**: `2026-08-01` (PR #32)
- **Observed Symptom**: Galera and master-slave replication nodes failed to authenticate during container initialization.
- **Root Cause Analysis**: `init-permissions.sql` hardcoded `rootpass` for `root@'%'`, whereas `.env` defines `DB_ROOT_PASSWORD`.
- **Applied Change / Fix**: Removed hardcoded password; `start_mariadb.sh` sets root password dynamically from `MARIADB_ROOT_PASSWORD`.
- **Result & Non-Regression Test**: Replication nodes bootstrap and authenticate correctly across all topologies.

### RCA-004 — Missing `CREATE USER` for `root@%` in MariaDB Setup
- **Date / Linked Action**: `2026-08-01` (PR #33)
- **Observed Symptom**: `GRANT ... TO 'root'@'%'` failed because `mariadb-install-db` only creates `root@localhost`.
- **Applied Change / Fix**: Added `CREATE USER IF NOT EXISTS 'root'@'%'` before all `GRANT` statements in `init-permissions.sql`.
- **Result & Non-Regression Test**: `test_repli.sh` passes user privilege checks on all replicas.

### RCA-005 — Permissive TLS Key Permissions in `gen_ssl_pgpool.sh`
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #56)
- **Observed Symptom**: `gen_ssl_pgpool.sh` applied `chmod 666` on private keys and `777` on directories.
- **Applied Change / Fix**: Enforced `chmod 600` on private keys and `chmod 755` on certificate directories with Docker fallback.
- **Result & Non-Regression Test**: Verified via `test_pgpool.sh` and SSL permission audit.

### RCA-006 — Insecure Password on CLI Warning in Test Logs
- **Date / Linked Action**: `2026-08-01` (PR #25, #26)
- **Observed Symptom**: `[Warning] Using a password on the command line interface can be insecure` polluted test output.
- **Applied Change / Fix**: Switched all test scripts and Make targets to use `MYSQL_PWD` and `PGPASSWORD` environment variables.
- **Result & Non-Regression Test**: Clean test logs across 32/32 tests in `test_secure_password.sh`.

### RCA-007 — Nested Source Regression in `mysql96` with `employees` Schema
- **Date / Linked Action**: `2026-08-01` (PR #28)
- **Observed Symptom**: Data injection skipped on `mysql96` due to schema syntax incompatibilities with `employees`.
- **Applied Change / Fix**: Makefile and tests automatically inject the standard `sakila` dataset for `mysql96`.
- **Result & Non-Regression Test**: `test_lab.py` and `test_employees_schema` validate row counts for either `employees` or `sakila`.

### RCA-008 — Deprecated MariaDB 11.8 Options in Configuration Templates
- **Date / Linked Action**: `2026-08-01` (PR #29)
- **Observed Symptom**: `--innodb-file-per-table` and `--innodb-flush-method` triggered deprecation warnings in MariaDB 11.8.
- **Applied Change / Fix**: Removed obsolete parameters from `gcustom_*.cnf`.
- **Result & Non-Regression Test**: MariaDB 11.8 starts cleanly without warning banners.

### RCA-009 — Missing Error Traps in Makefile SSL Setup Targets
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #54)
- **Observed Symptom**: SSL generation failures in `test-all-topologies` were ignored by `make`, continuing with broken certs.
- **Applied Change / Fix**: Appended explicit `|| exit 1` error guards to SSL prerequisite targets in `Makefile`.
- **Result & Non-Regression Test**: Build fails fast if any certificate step exits non-zero.

### RCA-010 — Silent Copy Failures in `scripts/gen_ssl_patroni.sh`
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #38)
- **Observed Symptom**: Certificate copy commands had `|| true`, masking file copy errors.
- **Applied Change / Fix**: Removed `|| true` masks and added explicit error verification on all copy steps.
- **Result & Non-Regression Test**: Zero silent copy failures across Patroni certificate setups.

### RCA-011 — Fragile HTML Report Parsing in `scripts/aggregate_reports.sh`
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #41)
- **Observed Symptom**: Unquoted paths broke on whitespace, and unconstrained `grep` counts produced false totals.
- **Applied Change / Fix**: Quoted all path variables and used `grep -oiw` with word boundaries.
- **Result & Non-Regression Test**: Accurate pass/fail counters in `make test-all-report`.

### RCA-012 — Masked Failures in MySQLTuner CI Target (`|| true`)
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #22)
- **Observed Symptom**: `mysqltuner-all` reported success in CI even when sub-audits failed.
- **Applied Change / Fix**: Removed error masking in Makefile and CI workflow.
- **Result & Non-Regression Test**: CI halts immediately on any tuning test failure.

### RCA-013 — Duplicated InnoDB Group Replication Wait Loop
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #55)
- **Observed Symptom**: 60s Group Replication `ONLINE` state polling was duplicated between setup and test scripts.
- **Applied Change / Fix**: Extracted shared `wait_for_innodb_gr_online` helper in `tests/lib/common.sh`.
- **Result & Non-Regression Test**: DRY replication wait loop with unified timeout and diagnostic output.

### RCA-014 — Chained Mongo Exec Fallbacks Duplicating Options
- **Date / Linked Action**: `2026-08-01` (Sourcery AI alert / PR #57)
- **Observed Symptom**: Chained `docker exec` calls in `conf/mongo-rs/setup_rs.sh` duplicated CLI arguments.
- **Applied Change / Fix**: Refactored command dispatch into a clean bash array iteration.
- **Result & Non-Regression Test**: Compact, readable container invocation with zero repetition.

---

### RCA-015 — Syntax Crash and Insecure Password Leakage in Legacy Scripts
- **Date / Linked Action**: `2026-10-30` (`ACT-007` / Issue `#68`)
- **Observed Symptom**: `mysql_docker.py` syntax error on `except e:` and exposed `-p"{password}"` in aliases; `interactive_runner.py` blocked CLI on input.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Unbound exception name `e` and inline password flags in shell alias generation.
- **Applied Change / Fix**: Replaced `except e:` with `except Exception as e:`, injected `MYSQL_PWD` in aliases, deferred interactive prompts to `main()`, and unified PKI generation in `scripts/gen_pki.sh`.
- **Result & Non-Regression Test**: All tests passed (`test_secure_password.sh`, `test_project_governance_rules.py`, `make test-config`).

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

### IMP-004 — Unpinned Container Image Tags (`:latest`)
- **Why It Is a Dead-End**: Using `:latest` tags makes deployments non-deterministic and can introduce breaking upstream changes silently.
- **Adopted Decision**: Pin all image tags explicitly (e.g. `pgpool/pgpool:4.6`).

### IMP-005 — Running Container Supervisors as Root User
- **Why It Is a Dead-End**: Root process execution inside containers violates container security standards (Sourcery AI PR #53 alert).
- **Adopted Decision**: Configure unprivileged user execution (`postgres`, `mysql`) in supervisor configuration files.

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

### APP-003 — Standalone Engine & Topology Baseline Verification (2026-08-01)
- **Target Files**: `tests/test_*.sh`, `Makefile`
- **Nature & Justification**: Baseline verified across standalone MySQL (9.6.0, 8.4.8, 8.0.45), MariaDB (11.8.6, 11.4.10, 10.11.16, 10.6.25), Percona (8.0.44), PostgreSQL (17.8, 16.12, 15.16), and all 6 HA topologies (Galera, Replication, Patroni, PgPool-II, InnoDB Cluster, MongoDB RS).
- **Removal Condition**: Continuous CI execution across all standalone versions.

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
