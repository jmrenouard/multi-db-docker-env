# POTENTIAL_ISSUES - System Audit & Sourcery AI Feedback Tracker

This file documents anomalies, warnings, security vulnerabilities, technical debt, and resolutions identified across all cluster technologies and code review campaigns (including all 99 feedback items from Sourcery AI).

## Critical / High Priority & Security Audits

| Issue | Component | Status | Description | Action Taken / Proposed |
| :--- | :--- | :--- | :--- | :--- |
| Permission Denied on cleanup | Makefile / Scripts | ✅ RESOLVED | `make clean-galera` and `make clean-repli` failed due to files being owned by root (via Docker). | Uses `docker run --rm alpine` to remove root-owned directories without requiring `sudo`. |
| Root Password Mismatch (Galera/Repli) | init-permissions.sql | ✅ RESOLVED | `init-permissions.sql` hardcoded `rootpass` for `root@'%'`, while `.env` uses `DB_ROOT_PASSWORD`. | Removed hardcoded password; `start_mariadb.sh` sets root password from `MARIADB_ROOT_PASSWORD`. |
| Missing CREATE USER for root@% | init-permissions.sql | ✅ RESOLVED | `GRANT ... TO 'root'@'%'` failed because `mariadb-install-db` only creates `root@localhost`. | Added `CREATE USER IF NOT EXISTS` before all `GRANT` statements. |
| Permissive TLS Key Permissions | `gen_ssl_pgpool.sh` | ✅ RESOLVED | `gen_ssl_pgpool.sh` sets `chmod 666` on keys and `777` on dir (Sourcery AI PR #56 alert). | Restrict key permissions to `600` and key directories to `755` with Docker fallback. |
| Root Execution in Supervisor | `conf/supervisord-patroni.conf` | ✅ RESOLVED | `supervisord` runs as root inside Patroni container (Sourcery AI PR #53 alert). | Formatted multiline env definitions and configured unprivileged user isolation. |
| Hardcoded PAT in Fix Scripts | `scripts/fix_issue.sh` | ✅ RESOLVED | GitHub Personal Access Tokens hardcoded in temporary scripts (Sourcery AI PR #25/#26 alert). | Removed token strings and loaded exclusively from `GITHUB_TOKEN` env var. |
| Hardcoded DB Credentials | `docker-compose-patroni.yml` | ✅ RESOLVED | Credentials embedded directly in compose file (Sourcery AI PR #24 alert). | Reference credentials from `.env` file across all compose services. |

## Warnings / Medium Priority & Bug Risks

| Issue | Component | Status | Description | Action Taken / Proposed |
| :--- | :--- | :--- | :--- | :--- |
| Insecure Password on CLI | MySQL/MariaDB | ✅ RESOLVED | Standard `[Warning] Using a password on CLI` in test logs. | Use `MYSQL_PWD` environment variable instead of inline CLI passwords (PR #25, #26). |
| Nested Source Regression | mysql96 | ✅ RESOLVED | `employees` data injection skipped for mysql96 due to known regression. | `Makefile` injects `sakila` dataset for mysql96 automatically (PR #28). |
| Deprecated MariaDB Options | MariaDB 11.8 | ✅ RESOLVED | `--innodb-file-per-table` and `--innodb-flush-method` deprecated in MariaDB 11.8. | Removed deprecated options from `gcustom_*.cnf` (PR #29). |
| Unpinned PgPool Image Tag | `docker-compose-pgpool.yml` | ✅ RESOLVED | Image uses `:latest` tag making deployments non-deterministic (Sourcery AI PR #56 alert). | Pinned `pgpool` image tag to `pgpool/pgpool:4.6`. |
| Missing Error Traps in Makefile | Makefile | ✅ RESOLVED | SSL generation steps in `test-all-topologies` lack `|| exit 1` error guards (Sourcery AI PR #54 alert). | Appended `|| exit 1` to all SSL setup target prerequisites in Makefile. |
| Silent Copy Failures | `gen_ssl_patroni.sh` | ✅ RESOLVED | Cert copy failures exit with status 0, masking misconfigurations (Sourcery AI PR #38 alert). | Added explicit error checks and removed `|| true` on certificate copy commands. |
| Fragile HTML Report Parsing | `aggregate_reports.sh` | ✅ RESOLVED | `grep` counting on raw pass/fail strings is fragile; unquoted file paths break on spaces (Sourcery AI PR #41 alert). | Quoted file variables and used `grep -oiw` with word boundaries. |
| Masked Failures in MySQLTuner | Makefile / CI | ✅ RESOLVED | `mysqltuner-all` target uses `|| true`, reporting success even when tests fail (Sourcery AI PR #22 alert). | Removed `|| echo` error mask in CI workflow. |

## Technical Debt & Code Maintenance

| Item | Component | Status | Description |
| :--- | :--- | :--- | :--- |
| Unified Test Framework | `tests/lib/common.sh` | ✅ RESOLVED | Extracted reusable assertion and summary functions (PR #40). |
| Test Report Aggregation | `scripts/aggregate_reports.sh` | ✅ RESOLVED | Consolidated HTML reports into unified dashboard via `make test-all-report` (PR #41). |
| Duplicated SSL_FLAGS | Test Scripts | ✅ RESOLVED | `SSL_FLAGS` check duplicated in test scripts (Sourcery AI PR #51/#52 alert). Extracted `init_ssl_flags` to `common.sh`. |
| Duplicated InnoDB Wait Loop | `setup_cluster.sh` / `test_innodb.sh` | ✅ RESOLVED | 60s Group Replication `ONLINE` state loop duplicated across setup and test scripts (Sourcery AI PR #55 alert). Extracted `wait_for_innodb_gr_online`. |
| Chained Mongo Exec Fallbacks | `conf/mongo-rs/setup_rs.sh` | ✅ RESOLVED | Chained `docker exec` fallbacks in `run_mongo`/`run_mongosh` duplicate options (Sourcery AI PR #57 alert). Refactored into array loop. |
| Fragile `.env` Parsing | `scripts/run_mysqltuner.sh` | ✅ RESOLVED | `.env` parsing via `grep | xargs` breaks on comments/quotes (Sourcery AI PR #22 alert). Updated pathing and env resolution. |
| Redundant Cert Generation | Makefile | ✅ RESOLVED | `innodb-up` always runs `gen-ssl-innodb` as hard prerequisite (Sourcery AI PR #35 alert). Certificates generated idempotently. |

## Documentation & Typo Corrections

| File | Issue Type | Description | Resolution Plan | Status |
| :--- | :--- | :--- | :--- | :--- |
| `documentation/tls_setup.md` | Typo | "Repli" abbreviation used instead of full term "Replication" (Sourcery AI PR #39 alert). | Replaced "Repli" with "Replication" and added relative path note. | ✅ RESOLVED |
| `README_fr.md` | Grammar | Grammatical agreement: "Optionnel" used with feminine noun "Optimisation" (Sourcery AI PR #30 alert). | Changed "Optionnel" to "Optionnelle". | ✅ RESOLVED |
| `ROADMAP.md` | Grammar | Noun "setup" used instead of verb phrase "set up" (Sourcery AI PR #22 alert). | Corrected verb usages across Markdown documentation. | ✅ RESOLVED |

---

## Test Results Summary (2026-08-01)

### Standalone Services (`make test-all`)
- ✅ **MySQL**: 9.6.0, 8.4.8, 8.0.45
- ✅ **MariaDB**: 11.8.6, 11.4.10, 10.11.16, 10.6.25
- ✅ **Percona Server**: 8.0.44-35
- ✅ **PostgreSQL**: 17.8, 16.12, 15.16

### High Availability Clusters & Verification
- ✅ **MariaDB Galera Cluster** (`make test-galera`): 3-node replication, router connectivity, TLS verification
- ✅ **MariaDB Replication** (`make test-repli`): Master-Slave replication, read-only enforcement
- ✅ **Patroni PostgreSQL** (`make test-patroni`): Leader election, etcd consensus, SAN TLS certs
- ✅ **PostgreSQL PgPool-II** (`make test-pgpool`): Load balancing, failover, TLS status check
- ✅ **MySQL InnoDB Cluster** (`make test-innodb`): Group Replication, `require_secure_transport=ON`
- ✅ **MongoDB Replica Set** (`make test-mongo`): Primary/Secondary election, `--tlsMode requireTLS`

