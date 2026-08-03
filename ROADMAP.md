# ROADMAP

## Phase 1 — Test Parity (Standardize all test suites)

Bring all HA cluster test suites to the same level of coverage without removing any existing test cases.

### Target Test Matrix

Every cluster test suite MUST include all categories below.

| # | Category | Description | Galera | Repli | Patroni | PgPool | InnoDB | MongoDB |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | Node Status | All nodes UP with version info | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | Cluster Status | Cluster/RS members online | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3 | Router Connectivity | HAProxy RW/RO ports verified | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4 | Write Replication | Write on primary replicated | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5 | Write Isolation | Read-only nodes reject writes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 6 | DDL Replication | Schema changes replicated | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 7 | CRUD Operations | Insert/Update/Delete on primary | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 8 | Version Consistency | Same version across all nodes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 9 | Concurrent Writes | N parallel inserts via router | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 10 | Config Consistency | Cluster config validated | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 11 | TLS/SSL Verification | TLS status on connections | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 12 | Performance Benchmark | Sysbench or equivalent | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 13 | HTML Report | Styled HTML output | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 14 | PASS/FAIL Counters | Structured pass/fail counting | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

> ✅ = 100% Implemented & Verified across all test suites (validated via automated E2E test suites and GitHub Actions CI workflow).

### Execution Order Guidelines

To execute or enrich test suites, follow this execution sequence:
1. **Pre-flight & Configuration Audit**: Run `make test-config` to validate environment files, compose syntax, and SSL certificates.
2. **Standalone Engine Validation**: Run `make test-all` across all standalone MySQL, MariaDB, Percona, and PostgreSQL instances.
3. **HA Cluster Engine Suites**: Run per-engine cluster test suites (`make test-galera`, `make test-repli`, `make test-innodb`, `make test-pgpool`, `make test-patroni`, `make test-mongo`).
4. **Resilience & Failover Validation**: Run `make test-failover` and `make test-backup-restore`.
5. **Full E2E Topology Audit**: Run `make test-all-topologies` for full cross-cluster validation and aggregated report generation.

---

## Phase 2 — TLS Generalization

Enable TLS/SSL across all products for encrypted client connections.

### Current TLS State

| Product | TLS Status | Mechanism |
| :--- | :--- | :--- |
| Galera | ✅ Implemented | `make gen-ssl`, mounted certs |
| Replication | ✅ Implemented | `make gen-ssl`, mounted certs |
| Patroni | ✅ Implemented | `make gen-ssl-patroni`, Docker-native SAN certs |
| PgPool-II | ✅ Implemented | `make gen-ssl-pgpool`, `PGPOOL_PARAMS_SSL=on` |
| InnoDB Cluster | ✅ Implemented | `make gen-ssl-innodb`, `require_secure_transport=ON` |
| MongoDB RS | ✅ Implemented | `make gen-ssl-mongo`, `--tlsMode requireTLS` |

### TLS Implementation Status

#### Phase 2.1 — InnoDB Cluster TLS (✅ Complete)
- Generate MySQL TLS certs via `make gen-ssl-innodb`
- Mount certs into MySQL 8.0 nodes
- Configure `require_secure_transport=ON`
- Add TLS verification to `test_innodb_cluster.sh`

#### Phase 2.2 — PgPool-II TLS (✅ Complete)
- Generate PostgreSQL TLS certs via `make gen-ssl-pgpool`
- Configure PgPool `ssl = on` and PG nodes `ssl = on`
- Add TLS verification to `test_pgpool.sh`

#### Phase 2.3 — MongoDB TLS (✅ Complete)
- Generate MongoDB TLS certs via `make gen-ssl-mongo`
- Add `--tlsMode requireTLS` to mongod command
- Mount PEM files into containers
- Add TLS verification to `test_mongo_rs.sh`

#### Phase 2.4 — Patroni Docker TLS (✅ Complete)
- Port Ansible TLS generation into Docker-native script
- Add `make gen-ssl-patroni` target
- Configure Patroni YAML for TLS
- Add TLS verification to `test_patroni.sh`

#### Phase 2.5 — Unified TLS Target (✅ Complete)
- Create `make gen-ssl-all` target calling all per-product TLS generators
- Create `make check-ssl-all` to verify TLS status across all clusters
- Document TLS architecture in `documentation/tls_setup.md`

---

## Phase 3 — Quality Improvements

| Item | Description | Priority | Status |
| :--- | :--- | :--- | :--- |
| Unified test framework | Shared test library (`tests/lib/common.sh`) with reusable functions | 🔴 HIGH | ✅ Complete |
| Test report aggregation | Single `make test-all-report` combining all HTML reports | 🟡 MEDIUM | ✅ Complete |
| Failover testing | Automated primary failover tests per cluster type | 🟡 MEDIUM | ✅ Complete |
| Backup/Restore tests | Verify backup and restore procedures per product | 🟢 LOW | ✅ Complete |
| CI/CD integration | GitHub Actions workflow for automated test execution | 🟢 LOW | ✅ Complete |
| Sourcery AI Code Hardening | Refactor TLS key permissions, pin PgPool tag, unify `SSL_FLAGS` helper | 🟡 MEDIUM | 🔄 In Progress |

---

## Phase 4 — MySQLTuner E2E Integration

> Bridge between multi-db-docker-env and MySQLTuner-perl for end-to-end validation of tuning diagnostics across HA topologies.

### MySQLTuner Audit Targets

| Target | Topology | Description | Status |
| :--- | :--- | :--- | :--- |
| `mysqltuner-galera` | Galera Cluster (3 nodes) | Start cluster, inject data, run MySQLTuner on all nodes | ✅ Complete |
| `mysqltuner-innodb` | InnoDB Cluster (3 nodes) | Start cluster, setup Group Replication, run MySQLTuner | ✅ Complete |
| `mysqltuner-repli` | Replication (3 nodes) | Start source + replicas, run MySQLTuner on each | ✅ Complete |
| `mysqltuner-all` | All topologies | Sequential audit of all HA topologies | ✅ Complete |

### Integration Architecture

```
multi-db-docker-env                    MySQLTuner-perl
┌──────────────────────┐              ┌──────────────────────┐
│ make mysqltuner-*    │──────────────│ mysqltuner.pl        │
│   → up-galera/innodb │   runs via   │   → Audit output     │
│   → inject data      │ MYSQLTUNER_  │   → HTML report      │
│   → run_mysqltuner.sh│ PATH env     │                      │
│   → reports/         │              │ build/test_ha.sh     │
└──────────────────────┘              │   → analyze_mt_output│
                                      │   → HA profiles      │
                                      └──────────────────────┘
```

### Implementation Status

- [x] `scripts/run_mysqltuner.sh` — Auto-detect topology and run MySQLTuner
- [x] Makefile targets — `mysqltuner-galera`, `mysqltuner-innodb`, `mysqltuner-repli`, `mysqltuner-all`
- [x] GitHub Actions workflow for automated MySQLTuner E2E testing
- [x] Cross-project HTML report aggregation

---

## Phase 5 — Sourcery AI Code Quality & Security Hardening (✅ Complete)

> Comprehensive resolution roadmap derived from auditing 99 feedback comments from Sourcery AI across 36 PRs ([documentation/sourcery_ai_audit.md](documentation/sourcery_ai_audit.md)).

### Phase 5.1 — Security & Access Control (✅ Complete)

- [x] **TLS Key Permissions**: Restrict key file permissions to `600` and key directories to `755` in `scripts/gen_ssl_pgpool.sh` (PR #56).
- [x] **Unprivileged Supervisor**: Formatted multiline environment variables and configured unprivileged user isolation in `conf/supervisord-patroni.conf` (PR #53).
- [x] **Clean Token References**: Removed hardcoded PAT references in utility scripts and force environment-only variable loading (PR #25/#26).
- [x] **Compose Credential Decoupling**: Externalized inline credentials in `docker-compose-patroni.yml` to `.env` variables (PR #24).

### Phase 5.2 — Reliability & Non-Deterministic Behaviors (✅ Complete)

- [x] **Pin Container Image Tags**: Replaced `pgpool:latest` with pinned release version tag `pgpool:4.6` in `docker-compose-pgpool.yml` (PR #56).
- [x] **Makefile Error Traps**: Added `|| exit 1` error guards to SSL setup prerequisites in `Makefile` `test-all-topologies` target (PR #54).
- [x] **Patroni SSL Failure Traps**: Added explicit error propagation and `chmod 600` on cert copy commands in `scripts/gen_ssl_patroni.sh` (PR #38).
- [x] **Robust HTML Report Aggregation**: Quoted path variables and used `grep -oiw` with word boundaries in `scripts/aggregate_reports.sh` (PR #41).
- [x] **MySQLTuner Failure Propagation**: Removed `|| echo` exit mask in CI workflow (PR #22).

### Phase 5.3 — Code Reuse & Maintainability (✅ Complete)

- [x] **Shared SSL Initialization**: Moved duplicate `SSL_FLAGS` logic into `init_ssl_flags` in `tests/lib/common.sh` (PR #51/#52).
- [x] **Shared Group Replication Wait Loop**: Extracted `wait_for_innodb_gr_online` helper and explicit error timeout handling in `setup_cluster.sh` and `test_innodb_cluster.sh` (PR #55).
- [x] **MongoDB Exec Loop**: Refactored chained `docker exec` fallbacks in `conf/mongo-rs/setup_rs.sh` into a clean bash array iteration (PR #57).
- [x] **Robust `.env` Parsing**: Standardized environment resolution in `scripts/run_mysqltuner.sh` (PR #22).
- [x] **Conditional Cert Generation**: Updated SSL generator scripts to execute idempotently (PR #35).

### Phase 5.4 — Documentation & Polish (✅ Complete)

- [x] **TLS Guide Typo**: Fixed "Repli" abbreviation to "Replication" and added relative path note in `documentation/tls_setup.md` (PR #39).
- [x] **French Grammar Correction**: Updated "Optionnel" to "Optionnelle" in `README_fr.md` (PR #30).
- [x] **Verb Usage Standardization**: Standardized "setup" vs "set up" usage across Markdown documentation (PR #22).
