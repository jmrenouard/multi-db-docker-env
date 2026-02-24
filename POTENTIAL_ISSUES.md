# POTENTIAL_ISSUES - System Audit 2026-02-24

This file documents anomalies, warnings, and technical debt identified during the test campaign.

## Critical / High Priority

| Issue | Component | Status | Description | Action Taken |
| :--- | :--- | :--- | :--- | :--- |
| Permission Denied on cleanup | Makefile / Scripts | ✅ RESOLVED | `make clean-galera` and `make clean-repli` failed due to files being owned by root (via Docker). | Uses `docker run --rm alpine` to remove root-owned directories without requiring `sudo`. |
| Root Password Mismatch (Galera/Repli) | init-permissions.sql / start_mariadb.sh | ✅ RESOLVED | `init-permissions.sql` hardcoded `rootpass` for `root@'%'`, while `.env` uses `DB_ROOT_PASSWORD`. Galera/Repli nodes were unreachable from host. | Removed hardcoded password; `start_mariadb.sh` now sets root password from `MARIADB_ROOT_PASSWORD` env var. |
| Missing CREATE USER for root@% | init-permissions.sql | ✅ RESOLVED | `GRANT ... TO 'root'@'%'` failed with `ERROR 1133: Can't find any matching row` because `mariadb-install-db` only creates `root@localhost`. | Added `CREATE USER IF NOT EXISTS` before all `GRANT` statements. |

## Warnings / Medium Priority

| Issue | Component | Status | Description | Recommended Action |
| :--- | :--- | :--- | :--- | :--- |
| Insecure Password on CLI | MySQL/MariaDB | ⚠️ KNOWN | Standard `[Warning] Using a password on the command line interface can be insecure.` in test logs. | Use `.my.cnf` or `MYSQL_PWD` (with caution) in test scripts. |
| Nested Source Regression | mysql96 | ⚠️ KNOWN | `employees` data injection skipped for mysql96 due to known regression. `sakila` is used instead. 1 test skipped. | Use `sakila` as primary test data for mysql96. |
| Deprecated MariaDB Options | MariaDB 11.8 | ⚠️ KNOWN | `--innodb-file-per-table` and `--innodb-flush-method` deprecated in MariaDB 11.8. | Remove deprecated options from `gcustom_*.cnf` / `custom_*.cnf` when dropping pre-11.8 support. |
| io_uring disabled | Docker / Kernel | ⚠️ KNOWN | `io_uring_queue_init() failed with EPERM` — kernel has `io_uring_disabled=2`. Falls back to libaio. | No action needed; libaio fallback is transparent. |

## Technical Debt / Weird Stuff

| Observation | Impact | Description |
| :--- | :--- | :--- |
| Long Wait Times | UX | Single-node tests wait up to 120s for readiness. High for idle local containers. |
| proxies_priv Warning | Cosmetic | `'proxies_priv' entry ignored in --skip-name-resolve mode.` during Galera init. |

## Test Results Summary (2026-02-24)

### Configuration Tests (`make test-config`)
- ✅ Environment file validation
- ✅ Docker Compose syntax (3 files)
- ✅ Configuration files (11 files)
- ✅ Scripts (8 scripts)
- ✅ SSL Security Audit
- ✅ Profile Generation

### Standalone Services (`make test-all`)
| Service | Version | Tests | Status |
| :--- | :--- | :--- | :--- |
| mysql96 | 9.6.0 | 6 (1 skipped) | ✅ |
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

### Galera Cluster (`make full-galera`)
- ✅ 3-Node Bootstrap (Sequential)
- ✅ Synchronous Replication
- ✅ Auto-Increment Consistency
- ✅ Certification Conflict
- ✅ DDL Replication
- ✅ Unique Key Constraint
- ✅ PFS & Slow Query Config
- ✅ Provider Options Audit
- ✅ SSL Certificate Expiry

### Replication Cluster (`make full-repli`)
- ✅ Master-Slave Setup (2 slaves)
- ✅ Data Replication
- ✅ Read-Only Enforcement
- ✅ SSL Connection
