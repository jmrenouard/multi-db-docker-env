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

> ✅ = 100% Implemented & Verified across all test suites

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

## Phase 5 — Sourcery AI Code Quality & Security Hardening

> Comprehensive resolution roadmap derived from auditing 99 feedback comments from Sourcery AI across 36 PRs ([documentation/sourcery_ai_audit.md](documentation/sourcery_ai_audit.md)).

### Phase 5.1 — Security & Access Control (🔴 High Priority)

- [ ] **TLS Key Permissions**: Restrict key file permissions to `600` and key directories to `700` in `scripts/gen_ssl_pgpool.sh` (PR #56).
- [ ] **Unprivileged Supervisor**: Configure `conf/supervisord-patroni.conf` to run under non-root account with targeted `sudo` escalation (PR #53).
- [ ] **Clean Token References**: Remove hardcoded PAT references in utility scripts and force environment-only variable loading (PR #25/#26).
- [ ] **Compose Credential Decoupling**: Externalize inline credentials in `docker-compose-patroni.yml` to `.env` variables (PR #24).

### Phase 5.2 — Reliability & Non-Deterministic Behaviors (🟡 Medium Priority)

- [ ] **Pin Container Image Tags**: Replace `pgpool:latest` with pinned release version tag `pgpool:4.5` in `docker-compose-pgpool.yml` (PR #56).
- [ ] **Makefile Error Traps**: Add `|| exit 1` error guards to SSL setup prerequisites in `Makefile` `test-all-topologies` target (PR #54).
- [ ] **Patroni SSL Failure Traps**: Add explicit error propagation on cert copy commands in `scripts/gen_ssl_patroni.sh` (PR #38).
- [ ] **Robust HTML Report Aggregation**: Quote path variables and parse structured JSON metadata in `scripts/aggregate_reports.sh` (PR #41).
- [ ] **MySQLTuner Failure Propagation**: Remove `|| true` exit masks from `mysqltuner-all` target in `Makefile` (PR #22).

### Phase 5.3 — Code Reuse & Maintainability (🟢 Technical Debt)

- [ ] **Shared SSL Initialization**: Move duplicate `SSL_FLAGS` logic from `test_galera.sh`, `test_repli.sh`, and `test_innodb.sh` into `tests/lib/common.sh` (PR #51/#52).
- [ ] **Shared Group Replication Wait Loop**: Extract the 60s `ONLINE` state loop into a shared helper function called by `setup_cluster.sh` and `test_innodb_cluster.sh` (PR #55).
- [ ] **MongoDB Exec Loop**: Refactor chained `docker exec` fallbacks in `conf/mongo-rs/setup_rs.sh` into a clean bash array iteration (PR #57).
- [ ] **Robust `.env` Parsing**: Replace `grep | xargs` in `scripts/run_mysqltuner.sh` with direct shell sourcing or array parsing (PR #22).
- [ ] **Conditional Cert Generation**: Update `innodb-up` target in `Makefile` to check for existing certs before regenerating (PR #35).

### Phase 5.4 — Documentation & Polish (🟢 Low Priority)

- [ ] **TLS Guide Typo**: Fix "Repli" abbreviation to "Replication" in `documentation/tls_setup.md` (PR #39).
- [ ] **French Grammar Correction**: Update "Optionnel" to "Optionnelle" in `README_fr.md` (PR #30).
- [ ] **Verb Usage Standardization**: Standardize "setup" vs "set up" usage across Markdown documentation (PR #22).

