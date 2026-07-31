# POTENTIAL_ISSUES - System Audit 2026-08-01

This file documents anomalies, warnings, technical debt, and resolutions identified across all cluster technologies and testing campaigns.

## Critical / High Priority

| Issue | Component | Status | Description | Action Taken |
| :--- | :--- | :--- | :--- | :--- |
| Permission Denied on cleanup | Makefile / Scripts | ✅ RESOLVED | `make clean-galera` and `make clean-repli` failed due to files being owned by root (via Docker). | Uses `docker run --rm alpine` to remove root-owned directories without requiring `sudo`. |
| Root Password Mismatch (Galera/Repli) | init-permissions.sql / start_mariadb.sh | ✅ RESOLVED | `init-permissions.sql` hardcoded `rootpass` for `root@'%'`, while `.env` uses `DB_ROOT_PASSWORD`. Galera/Repli nodes were unreachable from host. | Removed hardcoded password; `start_mariadb.sh` now sets root password from `MARIADB_ROOT_PASSWORD` env var. |
| Missing CREATE USER for root@% | init-permissions.sql | ✅ RESOLVED | `GRANT ... TO 'root'@'%'` failed with `ERROR 1133: Can't find any matching row` because `mariadb-install-db` only creates `root@localhost`. | Added `CREATE USER IF NOT EXISTS` before all `GRANT` statements. |
| TLS/SSL Infrastructure Parity | All HA Clusters | ✅ RESOLVED | End-to-end TLS transport was missing on InnoDB Cluster, PgPool-II, MongoDB RS, and Patroni. | Enabled TLS across all 5 cluster engines with unified `make gen-ssl-all` and `make check-ssl-all` targets (PRs #35, #36, #37, #38, #39). |
| CI/CD Pipeline Automation | GitHub Actions | ✅ RESOLVED | Automated CI pipeline was missing for testing, E2E MySQLTuner integration, and report aggregation. | Implemented `.github/workflows/ci.yml` running validation, TLS audit, backup/restore, failover, and MySQLTuner E2E tests (PRs #44, #45, #46, #47). |

## Warnings / Medium Priority

| Issue | Component | Status | Description | Action Taken |
| :--- | :--- | :--- | :--- | :--- |
| Insecure Password on CLI | MySQL/MariaDB | ⚠️ KNOWN | Standard `[Warning] Using a password on the command line interface can be insecure.` in test logs. | Use `.my.cnf` or `MYSQL_PWD` (with caution) in test scripts. |
| Nested Source Regression | mysql96 | ✅ RESOLVED | `employees` data injection skipped for mysql96 due to known regression. | `Makefile` injects `sakila` dataset for mysql96 automatically (PR #28). |
| Deprecated MariaDB Options | MariaDB 11.8 | ✅ RESOLVED | `--innodb-file-per-table` and `--innodb-flush-method` deprecated in MariaDB 11.8. | Removed deprecated options from `gcustom_*.cnf` (PR #29). |
| io_uring disabled | Docker / Kernel | ✅ RESOLVED | `io_uring_queue_init() failed with EPERM` — kernel has `io_uring_disabled=2`. Falls back to libaio. | Added fallback documentation to `README.md` and `README_fr.md` (PR #30). |

## Technical Debt & Enhancements

| Item | Status | Description |
| :--- | :--- | :--- |
| Unified Test Framework | ✅ RESOLVED | Extracted reusable assertion, report initialization, and summary functions into `tests/lib/common.sh` (PR #40). |
| Test Report Aggregation | ✅ RESOLVED | Consolidated individual HTML test reports into single HTML dashboard via `make test-all-report` (PR #41). |
| Automated Failover Testing | ✅ RESOLVED | Implemented primary failure simulation and election verification via `make test-failover` (PR #42). |
| Backup & Restore Verification | ✅ RESOLVED | Implemented script verification and backup execution tests via `make test-backup-restore` (PR #43). |

## Test Results Summary (2026-08-01)

### Configuration Tests (`make test-config`)
- ✅ Environment file validation
- ✅ Docker Compose syntax (all topologies)
- ✅ Configuration files
- ✅ Scripts & executable permissions
- ✅ SSL Security Audit
- ✅ Profile Generation

### Standalone Services (`make test-all`)
| Service | Version | Tests | Status |
| :--- | :--- | :--- | :--- |
| mysql96 | 9.6.0 | 6 | ✅ |
| mysql84 | 8.4.8 | 6 | ✅ |
| mysql80 | 8.0.45 | 6 | ✅ |
| mariadb118 | 11.8.6 | 6 | ✅ |
| mariadb114 | 11.4.10 | 6 | ✅ |
| mariadb1011 | 10.11.16 | 6 | ✅ |
| mariadb106 | 10.6.25 | 6 | ✅ |
| percona80 | 8.0.44-35 | 6 | ✅ |
| postgres17 | 17.8 | 1 | ✅ |
| postgres16 | 16.12 | 1 | ✅ |
| postgres15 | 15.16 | 1 | ✅ |

### High Availability Clusters & Verification
- ✅ **MariaDB Galera Cluster** (`make test-galera`): 3-node replication, router connectivity, concurrent writes, TLS/SSL verification
- ✅ **MariaDB Replication** (`make test-repli`): Master-Slave replication, read-only enforcement, TLS/SSL status check
- ✅ **Patroni PostgreSQL** (`make test-patroni`): Leader election, etcd consensus, concurrent writes, SAN TLS certificates
- ✅ **PostgreSQL PgPool-II** (`make test-pgpool`): Load balancing, failover, TLS status check, micro-benchmarks
- ✅ **MySQL InnoDB Cluster** (`make test-innodb`): Group Replication, `require_secure_transport=ON`, micro-benchmarks
- ✅ **MongoDB Replica Set** (`make test-mongo`): Primary/Secondary election, `--tlsMode requireTLS`, micro-benchmarks
- ✅ **Automated Failover** (`make test-failover`): Primary node failure simulation and recovery verification across all clusters
- ✅ **Backup & Restore** (`make test-backup-restore`): Script availability, usage interface, and backup creation verification
- ✅ **Report Aggregation** (`make test-all-report`): Glassmorphic HTML report compilation in `reports/latest_aggregated_report.html`
- ✅ **CI/CD Integration** (`.github/workflows/ci.yml`): Full pipeline execution with GitHub Actions
