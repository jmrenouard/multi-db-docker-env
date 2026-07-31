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
| 6 | DDL Replication | Schema changes replicated | ✅ | ✅ | ✅ | ★ | ✅ | ✅ |
| 7 | CRUD Operations | Insert/Update/Delete on primary | ✅ | ✅ | ✅ | ★ | ★ | ✅ |
| 8 | Version Consistency | Same version across all nodes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 9 | Concurrent Writes | N parallel inserts via router | ✅ | ✅ | ✅ | ★ | ✅ | ✅ |
| 10 | Config Consistency | Cluster config validated | ✅ | ✅ | ✅ | ✅ | ★ | ✅ |
| 11 | TLS/SSL Verification | TLS status on connections | ✅ | ✅ | ✅ | ★ | ★ | ✅ |
| 12 | Performance Benchmark | Sysbench or equivalent | ✅ | ✅ | ✅ | ★ | ★ | ✅ |
| 13 | HTML Report | Styled HTML output | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 14 | PASS/FAIL Counters | Structured pass/fail counting | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

> ✅ = already implemented | ★ = to add

### Execution Order

1. **Galera** (620 lines, rich but missing structured counters) — add PASS/FAIL, write isolation, DDL, CRUD, version, concurrent writes, config checks
2. **Repli** (353 lines) — same additions as Galera
3. **Patroni** (112 lines, minimal) — major enrichment needed: add all missing categories + HTML report
4. **PgPool** (459 lines, well-structured) — add DDL, CRUD, concurrent writes, TLS, performance
5. **InnoDB** (362 lines) — add CRUD, config consistency, TLS, performance
6. **MongoDB** (245 lines) — add DDL, concurrent writes, TLS, performance

---

## Phase 2 — TLS Generalization

Enable TLS/SSL across all products for encrypted client connections.

### Current TLS State

| Product | TLS Status | Mechanism |
| :--- | :--- | :--- |
| Galera | ✅ Implemented | `make gen-ssl`, mounted certs |
| Replication | ✅ Implemented | `make gen-ssl`, mounted certs |
| Patroni | ⚠️ Ansible-only | Ansible role generates certs |
| PgPool-II | ❌ Not implemented | — |
| InnoDB Cluster | ❌ Not implemented | — |
| MongoDB RS | ❌ Not implemented | — |
| Standalone MySQL/MariaDB | ❌ Not implemented | — |
| Standalone PostgreSQL | ❌ Not implemented | — |

### TLS Implementation Phases

#### Phase 2.1 — InnoDB Cluster TLS
- Generate MySQL TLS certs via `make gen-ssl-innodb`
- Mount certs into MySQL 8.0 nodes
- Configure `require_secure_transport=ON`
- Add TLS verification to `test_innodb_cluster.sh`

#### Phase 2.2 — PgPool-II TLS
- Generate PostgreSQL TLS certs via `make gen-ssl-pgpool`
- Configure PgPool `ssl = on` and PG nodes `ssl = on`
- Add TLS verification to `test_pgpool.sh`

#### Phase 2.3 — MongoDB TLS
- Generate MongoDB TLS certs via `make gen-ssl-mongo`
- Add `--tlsMode requireTLS` to mongod command
- Mount PEM files into containers
- Add TLS verification to `test_mongo_rs.sh`

#### Phase 2.4 — Patroni Docker TLS
- Port Ansible TLS generation into Docker-native script
- Add `make gen-ssl-patroni` target
- Configure Patroni YAML for TLS
- Add TLS verification to `test_patroni.sh`

#### Phase 2.5 — Unified TLS Target
- Create `make gen-ssl-all` target calling all per-product TLS generators
- Create `make check-ssl-all` to verify TLS status across all clusters
- Document TLS architecture in `documentation/tls_setup.md`

---

## Phase 3 — Quality Improvements

| Item | Description | Priority |
| :--- | :--- | :--- |
| Unified test framework | Shared test library (`tests/lib/common.sh`) with reusable functions | 🔴 HIGH |
| Test report aggregation | Single `make test-all-report` combining all HTML reports | 🟡 MEDIUM |
| Failover testing | Automated primary failover tests per cluster type | 🟡 MEDIUM |
| Backup/Restore tests | Verify backup and restore procedures per product | 🟢 LOW |
| CI/CD integration | GitHub Actions workflow for automated test execution | 🟢 LOW |

---

## Phase 4 — MySQLTuner E2E Integration

> Bridge between multi-db-docker-env and MySQLTuner-perl for end-to-end validation of tuning diagnostics across HA topologies.

### MySQLTuner Audit Targets

| Target | Topology | Description |
| :--- | :--- | :--- |
| `mysqltuner-galera` | Galera Cluster (3 nodes) | Start cluster, inject data, run MySQLTuner on all nodes |
| `mysqltuner-innodb` | InnoDB Cluster (3 nodes) | Start cluster, setup Group Replication, run MySQLTuner |
| `mysqltuner-repli` | Replication (3 nodes) | Start source + replicas, run MySQLTuner on each |
| `mysqltuner-all` | All topologies | Sequential audit of all HA topologies |

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
- [ ] GitHub Actions workflow for automated MySQLTuner E2E testing
- [ ] Cross-project HTML report aggregation

