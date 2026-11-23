# Action Logbook & Strategic Roadmap — Multi-DB Docker Environment

> **Governance Rule ([`AGENTS.md`](../AGENTS.md) §3 & [`.agents/rules/project-governance.md`](../.agents/rules/project-governance.md))**:
> This Action Logbook & Strategic Roadmap **MUST be systematically updated on every request, every change, and every result**:
> - New requests are logged under **"1. Ongoing Actions (`IN PROGRESS`)"** as soon as a GitHub Issue is opened.
> - Once validated by tests and merged via Pull Request, entries are completed with **Changes** and **Result** under **"2. Completed Actions (`COMPLETED`)"**.
> - The strategic roadmap and phase milestones below are kept in sync with development progress.

---

## 🗺️ Strategic Roadmap & Milestones

### Executive Phase Progress Dashboard

| Phase | Milestone Title | Target / Scope | Status | Verification Target |
| :--- | :--- | :--- | :---: | :--- |
| **Phase 1** | Test Parity across all HA Topologies | Galera, Repli, Patroni, PgPool, InnoDB, Mongo | ✅ Complete | `make test-all-topologies` |
| **Phase 2** | TLS Generalization & SAN Certs | End-to-end encrypted client connections | ✅ Complete | `make check-ssl-all` |
| **Phase 3** | Quality Improvements & Unified Testing | Shared test library, report aggregation, failover | ✅ Complete | `make test-all-report` |
| **Phase 4** | MySQLTuner E2E Topology Integration | Cross-project tuning audit integration | ✅ Complete | `make mysqltuner-all` |
| **Phase 5** | Sourcery AI Code & Security Hardening | 99 code review findings resolved across 36 PRs | ✅ Complete | `documentation/sourcery_ai_audit.md` |
| **Phase 6** | Governance & Engineering Standards | CIS Benchmarks rules, `< 15K` diff limit, registers | ✅ Complete | `python -m unittest discover -s tests -v` |
| **Phase 7** | Golang v2.0.0 Migration & Orchestrator | Statically compiled CLI, native PKI, verifiers, reports | ✅ Complete | `make test-go` |
| **Phase 8** | PostgreSQL Multi-Master & Distributed SQL (`v2.1.0`) | `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, `yugabyte`, benchmarks | ✅ Complete | `make bench-pg-multimaster` |
| **Phase 9** | PostgreSQL Streaming, Logical, Extended Matrix & V2 Benchmarks (`v2.2.0`) | `pg-streaming`, `pg-logical`, `T11`-`T18` matrix, V2 suites (`E2`-`E4`, `H`, `G`, WAN `10/25/50ms`) | ✅ Complete | `make test-pg-extended`, `make bench-pg-v2` |
| **Phase 10** | Ponytail Quality Audit, Release CI, Test Expansion & Governance Consolidation | Automated release pipeline, 18 audit fixes, 46 Python + 9 Go test suites, unified registers | ✅ Complete | `python -m unittest discover -s tests -v`, `go test ./...` |
| **Phase 11** | PostgreSQL 18.6 Native Topologies, Benchmark Suite & `v2.3.0` Release | `pg18-streaming`, `pg18-logical`, `pg18-birep` (`uuidv7`), `bench-pg18`, Go CLI 19 topologies, `v2.3.0` tag | ✅ Complete | `make bench-pg18`, `go test ./...`, `./bin/mdb topologies` |
| **Phase 12** | Database Version Upgrades & EOL Decommissioning | Upgrade to MySQL 8.4/9.7 LTS, MariaDB 12.3 LTS, Percona 8.4 LTS, PG 18 standalone, CockroachDB v25.4, Traefik v3, HAProxy LTS; decommission 7 EOL versions | ✅ Complete | `python -m unittest discover -s tests -v`, `go test ./...`, CI `test-and-validate` |
| **Phase 13** | YT Cluster 1.21.3 (PG 18) Active-Active Topology & `v2.4.0` / `v2.4.1` | 3-node `yt-cluster` Compose stack, setup, `L1-L8`/`T11-T18`/`T_REVERT` tests, 36-row `bench-yt-cluster`, Go CLI 20 topologies | ✅ Complete | `make yt-cluster-test`, `make bench-yt-cluster`, `go test ./...`, `./bin/mdb topologies` |
| **Phase 14** | Unified `./mdb` CLI, 12 Usability Audit Fixes & `v2.5.0` Release | `pkg/catalog`, unified `./mdb`/`mdb.cmd`, bilingual wizard, 13 PG stack wrappers, `make lint`/`test`, EN/FR docs, `v2.5.0` sync | ✅ Complete | `python -m unittest discover -s tests -v`, `go test ./...`, CI `test-and-validate` |
| **Phase 15** | Durable Production-Tuned PG Compose Stacks & Unified 18-Topology Benchmark Harness (`v2.6.0`) | Tuned 13 PG Compose stacks (`fsync`/`RPO=0` preserved), YB/CRDB HAProxy LBs, `bench_pg_optimized_*` (`PG_SCALE=20`, `--resume`), unit/static tests, EN/FR docs, `v2.6.0` tag | ✅ Complete | `make bench-pg-optimized`, `bash ./tests/test_config.sh`, `python -m unittest`, `go test ./...` |
| **Phase 16** | Self-Contained Patroni Images, `mdb images` CLI & 31/31 Live E2E Parity (`v2.6.1`) | 3 non-root Patroni Dockerfiles + `Dockerfile.bench`, `mdb images` CLI (`31/31` images), Patroni 4.x/mTLS live E2E, EN/FR docs & governance | ✅ Complete | `./mdb images check`, `./mdb test patroni --suite`, `go test ./...`, `python -m unittest` |
| **Phase 17** | Documentation Audit Remediation, ASD-STE100 Parity, Diataxis Indexing & Hygiene Gate (`v2.6.3`) | Fix links/anchors/rules, remove dead audit logs, achieve 0 STE errors across 21 EN/FR docs, Diataxis `INDEX*`, add `test_docs_hygiene.py` & CI step, release `v2.6.3` | Complete | `python -W error::ResourceWarning -m unittest discover -s tests -v`, `release_notes.py --tag v2.6.3 --check` |
| **Phase 18** | Transparent Data Encryption (TDE) Documentation Parity & `v2.6.4` Release | EN/FR `tde_encryption*.md` guides, `TDE` product matrices, TLS layer note, `INDEX*` & `pg_multimaster*` links, `APP-032`/`IDEA-015`, release `v2.6.4` | Complete | `ste_check.py --no-vocab`, `python -W error::ResourceWarning -m unittest discover -s tests -v`, `release_notes.py --tag v2.6.4 --check` |

---

### Detailed Milestones & Architecture

#### Phase 1: Test Parity Matrix (✅ Complete)
- All HA cluster test suites (`test_galera.sh`, `test_repli.sh`, `test_patroni.sh`, `test_pgpool.sh`, `test_innodb_cluster.sh`, `test_mongo_rs.sh`) share complete parity across 14 categories: Node Status, Cluster Status, Router Connectivity, Write Replication, Write Isolation, DDL Replication, CRUD Operations, Version Consistency, Concurrent Writes, Config Consistency, TLS/SSL Verification, Performance Benchmark, HTML Report, and Structured PASS/FAIL Counters.
- **Execution Order**:
  1. `make test-config` (Configuration and directory audit)
  2. `make test-all` (Standalone MySQL, MariaDB, Percona, PostgreSQL)
  3. Per-cluster targets (`make test-galera`, `make test-repli`, `make test-innodb`, `make test-pgpool`, `make test-patroni`, `make test-mongo`)
  4. Resilience & failover (`make test-failover`, `make test-backup-restore`)
  5. Consolidated run (`make test-all-topologies`)

#### Phase 2: TLS Generalization (✅ Complete)
- Galera & Replication: mounted TLS certs via `make gen-ssl`.
- Patroni: Docker-native SAN certs via `make gen-ssl-patroni`.
- PgPool-II: `make gen-ssl-pgpool`, `PGPOOL_PARAMS_SSL=on`.
- InnoDB Cluster: `make gen-ssl-innodb`, `require_secure_transport=ON`.
- MongoDB ReplicaSet: `make gen-ssl-mongo`, `--tlsMode requireTLS`.
- Unified targets: `make gen-ssl-all` and `make check-ssl-all`.

#### Phase 3: Quality Improvements & Automation (✅ Complete)
- Shared bash test library (`tests/lib/common.sh`) with standardized assertions.
- Consolidated dashboard reporting via `make test-all-report` (`scripts/aggregate_reports.sh`).
- Automated primary failover tests (`make test-failover`) and backup/restore tests (`make test-backup-restore`).
- GitHub Actions CI workflow (`.github/workflows/ci.yml`).

#### Phase 4: MySQLTuner E2E Integration (✅ Complete)
- Bridge between `multi-db-docker-env` and `MySQLTuner-perl` via `scripts/run_mysqltuner.sh`.
- Makefile audit targets: `mysqltuner-galera`, `mysqltuner-innodb`, `mysqltuner-repli`, `mysqltuner-all`.

#### Phase 5: Sourcery AI Security & Quality Hardening (✅ Complete)
- Security: TLS key permissions restricted to `600`, key directories to `755` (`scripts/gen_ssl_pgpool.sh`); unprivileged supervisor isolation (`conf/supervisord-patroni.conf`); clean token environment references; `.env` credential decoupling.
- Reliability: Pinned container tags (`pgpool:4.6`); Makefile error guards (`|| exit 1`); robust HTML report aggregation with word boundaries; clean CI failure propagation.
- Maintainability: Unified `SSL_FLAGS` initialization (`tests/lib/common.sh`); shared Group Replication online loop (`wait_for_innodb_gr_online`); array loop for MongoDB fallbacks.

#### Phase 6: Project Governance & Engineering Standards (✅ Complete)
- Reintegrated and aligned with CIS Benchmarks development framework: English documentation, `< 15,000` character PR diff limits, 8-step GitHub lifecycle, living Action Logbook and RCA Register, and automated unit tests (`tests/test_project_governance_rules.py`).

#### Phase 7: Golang v2.0.0 Migration & Orchestrator (✅ Complete)
- Major migration to statically compiled pure-Go CLI (`bin/mdb`), typed config (`pkg/config`), native x509 PKI (`pkg/pki`), declarative topologies (`pkg/topology`), pure-Go database health verifiers (`pkg/dbclient`), concurrent runner pipeline (`pkg/runner`), sysbench collector (`pkg/bench`), and embedded HTML reporting (`pkg/report`). Verified via `make test-go` with 0 data races.

---

## 1. Ongoing Actions (`IN PROGRESS`)

| Action ID | Date / Time (ISO) | Issue / Branch | Status | Request, Ongoing Changes & Expected Results |
| :--- | :--- | :--- | :--- | :--- |
| *None* | — | — | — | All current actions are completed and archived below. |

## 2. Completed Actions (`COMPLETED`)

### ACT-170 -- Add Diataxis Portal Index and README Portal Links (`#535`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:25Z` | Issue `#535` | `docs/issue-535-diataxis-portal`
- **Request**: Add `docs/index.md` portal landing page and link the live Diataxis portal (`multi-db-docker-env.lightpath.fr`) from `README.md` and `README_fr.md` with 0 STE errors.
- **Changes**: Added `docs/index.md` and updated `README.md` and `README_fr.md` with Docs badges and Diataxis links.
- **Result**: `diataxis_check.py --strict --check-ste` (`0` errors, `22` files), `mkdocs build --strict` (`52` pages OK), `unittest` 79 OK, `/ponytail-review` `APPROVE`, diff `< 11,500` B.

### ACT-169 -- Add Multi-Version MkDocs Material Builder for IONOS (`#531`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:23Z` | Issue `#531` | `feat/issue-531-versioned-docs-builder`
- **Request**: Add `scripts/build_versioned_docs.py` building `main` + semver tags `>= v2.3.0`, `versions.json`, `.htaccess`, redirects, and zip/secret guards.
- **Changes**: Added `scripts/build_versioned_docs.py` (`211` lines).
- **Result**: Multi-version build (`main`, `v2.6.4`, `v2.3.0`) OK; security guards OK; `unittest` 79 OK; `/ponytail-review` `APPROVE`; diff `< 14,000` B.

### ACT-168 -- Add Diataxis Sandbox Tutorials & Environment TLS Matrix (`#534`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:17Z` | Issue `#534` | `docs/issue-534-diataxis-tutorials`
- **Request**: Add 3 `01-tutorials/` labs (`01-local-sandbox-setup.md`, `02-first-ha-failover-lab.md`, `03-postgres-multimaster-lab.md`) + `03-reference/configuration/environment-and-tls-matrix.md` and update indexes.
- **Changes**: Added all 4 pages (with `"HEALTHY"` casing fix in `03-postgres-multimaster-lab.md`) and updated `01-tutorials/index.md` + `03-reference/index.md`.
- **Result**: 0 STE errors (`ste_check.py`), `unittest` 79 OK (6 skipped) on system + venv Python, `/ponytail-review` `APPROVE`, diff `< 13,000` B.

### ACT-167 -- Add MkDocs Material Build Hooks for Virtual Docs & Link Rewriting (`#528`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:16Z` | Issue `#528` | `feat/issue-528-mkdocs-hooks`
- **Request**: Add lazy-imported `scripts/mkdocs_hooks.py` for virtual docs, `documentation/*.md` injection, GFM slugs/alerts, link rewriting, and nav pruning.
- **Changes**: Added `scripts/mkdocs_hooks.py` (`237` lines).
- **Result**: Bare import OK; `mkdocs build --strict` (47 pages) + `v2.3.0..v2.6.4` builds OK; `unittest` 79 OK; `/ponytail-review` `APPROVE`; diff `< 14,000` B.

### ACT-166 -- Add Diataxis Explanation Architecture Overview, ADRs & Deep Dive (`#532`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:08Z` | Issue `#532` | `docs/issue-532-diataxis-explanation`
- **Request**: Add 4 `04-explanation/` pages (`global-topology-and-routing.md`, `adr-001`, `adr-002`, `quorum-replication-and-tls.md`) matching `mkdocs.yml` paths and wire links.
- **Changes**: Added the 4 Explanation pages (with `26` file count fix in `adr-002`) and updated `04-explanation/index.md` + 4 How-To Explanation links.
- **Result**: 0 STE errors (`ste_check.py`), `unittest` 79 OK (6 skipped) on system + venv Python, `/ponytail-review` `APPROVE`, diff `< 14,000` B.

### ACT-165 -- Add Diataxis Reference Architecture, CLI & Error Matrices (`#529`)
- **Timestamp / Issue / Branch**: `2026-11-23T20:01Z` | Issue `#529` | `docs/issue-529-diataxis-reference`
- **Request**: Add 3 Diataxis Reference pages (`topology-and-port-matrix.md`, `mdb-cli-and-makefile-reference.md`, `error-and-alert-matrix.md`) and wire links from `03-reference/index.md` and `02-how-to-guides/`.
- **Changes**: Added the 3 Reference specs and updated `docs/03-reference/index.md` + 4 How-To guide Reference footers.
- **Result**: 0 STE errors (`ste_check.py`), `unittest` 79 OK (6 skipped) on system + venv Python, `/ponytail-review` `APPROVE`, diff `< 14,000` B.

### ACT-164 -- Add MkDocs Material Config, Docs-as-Code Linters & Portal Assets (`#524`)
- **Timestamp / Issue / Branch**: `2026-11-23T19:54Z` | Issue `#524` | `feat/issue-524-mkdocs-config`
- **Request**: Configure 5 IONOS GitHub Secrets and add `mkdocs.yml`, `requirements-docs.txt`, `.vale.ini`, `.markdownlint.json`, `.gitignore`, KaTeX/CSS, and SVGs.
- **Changes**: Added PR 1 config/assets (`#524`), fixed KaTeX load order (`RCA-141`), and provisioned 5 `IONOS_*` GitHub Secrets.
- **Result**: `unittest` 79 OK (6 skipped) on system + venv Python, `/ponytail-review` `APPROVE`, diff `< 14,500` B.

### ACT-163 -- Add Diataxis Quadrant Indexes and 4 STE How-To Guides (`#525`)
- **Timestamp / Issue / Branch**: `2026-11-23T19:52Z` | Issue `#525` | `docs/issue-525-diataxis-guides`
- **Request**: Add 4 Diataxis quadrant `index.md` stubs and 4 ASD-STE100 How-To guides (`03-reference/*` split to PR 4b).
- **Changes**: Added `docs/0{1-tutorials,2-how-to-guides,3-reference,4-explanation}/index.md`, 4 `docs/02-how-to-guides/*/*.md` guides, and `RCA-140`.
- **Result**: 0 STE errors (`ste_check.py`), `unittest` 79 OK (6 skipped), `/ponytail-review` `APPROVE`, diff `< 14,500` B.

### ACT-162 -- Prepare Release `v2.6.4` TDE Documentation Parity (`#522`)
- **Timestamp / Issue / Branch**: `2026-11-23T19:07Z` | Issue `#522` | `chore/issue-522-release-v2-6-4`
- **Request**: Synchronize `v2.6.4` release metadata across `VERSION`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, `README.md`, `README_fr.md`, `ROADMAP.md`, prepend `2.6.4 2026-11-23` to `Changelog` (`<= 600` lines FIFO), and record Phase 18.
- **Changes**: Bumped `2.6.3` -> `2.6.4` in `VERSION`, Go CLI/tests, EN/FR READMEs, and `ROADMAP.md`; linked `tde_encryption*.md` in READMEs; prepended ordered `2.6.4 2026-11-23` notes to `Changelog`; recorded Phase 18 milestone.
- **Result**: Verified `python3 scripts/release_notes.py --tag v2.6.4 --check`, `go run ./cmd/mdb --version`, Windows + WSL `unittest`, `test_config.sh`, `go test`, `./mdb lint`, and diff `< 14,800` B.

### ACT-161 -- Add TDE Matrix to `supported_products_fr.md`, PG Multi-Master Notes & RCA Entries (`#520`)
- **Timestamp / Issue / Branch**: `2026-11-23T19:03Z` | Issue `#520` | `docs/issue-520-tde-matrices-fr-and-pg`
- **Request**: Complete Part 2 of TDE cross-linking: add `TDE` column to `documentation/supported_products_fr.md`, add TDE note to `documentation/pg_multimaster.md` and `pg_multimaster_fr.md`, and add `APP-032`/`IDEA-015` to `docs/RCA_REGISTER.md` (`< 14,800` B).
- **Changes**: Updated `documentation/supported_products_fr.md`, `documentation/pg_multimaster.md`, `documentation/pg_multimaster_fr.md`, and logged `APP-032`/`IDEA-015` in `docs/RCA_REGISTER.md`.
- **Result**: Verified 0 STE errors (`ste_check.py --mode procedural --no-vocab`), Windows + WSL `unittest`, `test_config.sh`, `go test`, `./mdb lint`, and diff `< 14,800` B.

### ACT-160 -- Add TDE Matrix to `supported_products.md`, TLS Layer Note & Index Links (`#518`)
- **Timestamp / Issue / Branch**: `2026-11-23T18:59Z` | Issue `#518` | `docs/issue-518-tde-matrices-and-index`
- **Request**: Add `TDE` column to `documentation/supported_products.md`, add transport-vs-TDE section to `documentation/tls_setup.md`, and register `tde_encryption*.md` in `documentation/INDEX.md` and `INDEX_fr.md` (`supported_products_fr.md`, `pg_multimaster*.md`, and `RCA_REGISTER.md` follow in the next atomic PR to keep diff `< 14,800` B).
- **Changes**: Updated `documentation/supported_products.md`, `documentation/tls_setup.md`, `documentation/INDEX.md`, and `documentation/INDEX_fr.md`.
- **Result**: Verified 0 STE errors (`ste_check.py --no-vocab`), Windows + WSL `unittest`, `test_config.sh`, `go test`, `./mdb lint`, and diff `< 14,800` B.

### ACT-159 -- Add Bilingual TDE and Data-at-Rest Encryption Reference Guides (`#516`)
- **Timestamp / Issue / Branch**: `2026-11-23T18:52Z` | Issue `#516` | `docs/issue-516-tde-encryption-guide`
- **Request**: Author EN/FR TDE and data-at-rest guides covering layers, MySQL, MariaDB, Percona, PostgreSQL (`pg_tde` 2.1, Distributed SQL), and MongoDB with 0 STE errors and register them in `tests/test_docs_hygiene.py`.
- **Changes**: Created `documentation/tde_encryption.md` and `documentation/tde_encryption_fr.md` and registered both in `MIXED_STE_DOCS` inside `tests/test_docs_hygiene.py`.
- **Result**: Verified 0 STE errors (`ste_check.py --mode mixed --no-vocab`), Windows + WSL `unittest`, `test_config.sh`, `go test`, `./mdb lint`, and diff `< 14,800` B.

### ACT-158 -- Prepare Release `v2.6.3` Documentation Audit, STE Parity, and CI Gate (`#514`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:34Z` | Issue `#514` | `chore/issue-514-release-v2-6-3`
- **Request**: Synchronize `v2.6.3` release metadata across `VERSION`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, `README.md`, `README_fr.md`, `ROADMAP.md`, prepend `2.6.3 2026-11-22` to `Changelog` (`<= 600` lines FIFO), and finalize Phase 17 registers.
- **Changes**: Bumped `2.6.2` -> `2.6.3` in `VERSION`, Go CLI/tests, EN/FR READMEs, and `ROADMAP.md`; prepended ordered `2.6.3 2026-11-22` notes to `Changelog`; recorded Phase 17 milestone and `RCA-139`.
- **Result**: Verified `python3 scripts/release_notes.py --tag v2.6.3 --check`, `go run ./cmd/mdb --version`, Windows + WSL `unittest` (79 OK, 6 live-DB skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-157 -- Add Automated Documentation Hygiene Gate and CI Step (`#512`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:28Z` | Issue `#512` | `ci/issue-512-docs-hygiene-gate`
- **Request**: Implement stdlib `tests/test_docs_hygiene.py` (links, GFM anchors, `file:///`, `Makefile` targets, root duplicate rules, `CAUTION`/`ATTENTION` warnings, and STE structural rules) and add `python3 -W error::ResourceWarning -m unittest discover -s tests -v` to `.github/workflows/ci.yml`.
- **Changes**: Created `tests/test_docs_hygiene.py` covering 6 deterministic doc gates across tracked `.md` and 21 cleaned docs, and added Python unittest CI step in `.github/workflows/ci.yml`; logged `RCA-138`.
- **Result**: Verified Windows + WSL `unittest` (including all 6 `TestDocsHygiene` checks passing non-skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-156 -- Align `pg_multimaster_fr.md` Part 3 (YT Cluster and `v2.6.0`) with ASD-STE100 (`#510`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:22Z` | Issue `#510` | `docs/issue-510-pg-multimaster-fr-part3`
- **Request**: Bring `YT Cluster 1.21.3` and `Piles durcies` (`v2.6.0`) in `documentation/pg_multimaster_fr.md` to `0` STE errors and `0` `via`/weak modals.
- **Changes**: Split YT Cluster, RAM caps, HAProxy, and engine bullets into `<= 20`-word French sentences without semicolons or `via`; logged `RCA-137`.
- **Result**: Verified full-file `0 errors, 0 warnings` (`ste_check.py`), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-155 -- Align `pg_multimaster_fr.md` Part 2 (V2 Matrix and PG 18.6) with ASD-STE100 (`#508`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:18Z` | Issue `#508` | `docs/issue-508-pg-multimaster-fr-part2`
- **Request**: Refactor `Matrice etendue V2` + `bench-pg-v2` and `Topologies natives PostgreSQL 18.6` in `documentation/pg_multimaster_fr.md` into `<= 20`-word French STE sentences without semicolons (`YT Cluster` + `v2.6.0` follow in Part 3).
- **Changes**: Split semicolon-chained V2 `T11`-`T18`, `bench-pg-v2`, and PG 18.6 bullets into short active French sentences while preserving every metric and SQLSTATE verbatim; logged `RCA-136`.
- **Result**: Verified 0 STE errors up to `## Pile actif-actif YT Cluster` (`ste_check.py --mode procedural --lang fr --no-vocab`), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-154 -- Align `pg_multimaster_fr.md` Part 1 (Overview & Empirical Limits) with ASD-STE100 (`#506`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:14Z` | Issue `#506` | `docs/issue-506-pg-multimaster-fr-part1`
- **Request**: Refactor `documentation/pg_multimaster_fr.md` overview, V1 takeaways, and Empirical Limits into `<= 20`-word French STE sentences without semicolons and update `v2.5.0` -> `v2.6.2` (V2/PG18 and YT/`v2.6.0` follow in Part 2/3 PRs).
- **Changes**: Updated L3/L30 (`v2.6.2`), shortened L52, and split takeaways and empirical SQLSTATE bullets into <= 20-word sentences without semicolons in `documentation/pg_multimaster_fr.md`; logged `RCA-135`.
- **Result**: Verified 0 STE errors up to `## Matrice` (`ste_check.py --mode procedural --lang fr --no-vocab`), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-153 -- Align `pg_multimaster.md` Part 3 (YT Cluster and `v2.6.0`) with ASD-STE100 (`#504`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:10Z` | Issue `#504` | `docs/issue-504-pg-multimaster-en-part3`
- **Request**: Refactor `YT Cluster 1.21.3` and `Durable Production-Tuned Stacks` (`v2.6.0`) in `documentation/pg_multimaster.md` so the full file achieves `0` STE procedural errors (`ste_check.py --mode procedural --lang en --no-vocab`).
- **Changes**: Split YT Cluster, RAM caps, HAProxy, and engine optimization bullets into `<= 20`-word STE sentences without semicolons or possessives while retaining every port, parameter, and metric verbatim; logged `RCA-134`.
- **Result**: Verified full-file `ste_check.py --mode procedural --lang en --no-vocab documentation/pg_multimaster.md` (`0 errors`), 0 forbidden words, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-152 -- Align `pg_multimaster.md` Part 2 (V2 Matrix and PG 18.6) with ASD-STE100 (`#502`)
- **Timestamp / Issue / Branch**: `2026-11-23T00:06Z` | Issue `#502` | `docs/issue-502-pg-multimaster-en-part2`
- **Request**: Refactor `V2 Extended Matrix (T11-T18)` + `bench-pg-v2` and `PostgreSQL 18.6 Native Stacks` sections of `documentation/pg_multimaster.md` into `<= 20`-word active STE sentences without semicolons (`YT Cluster` + `v2.6.0` follow in Part 3).
- **Changes**: Split semicolon-chained `T11`-`T18`, `bench-pg-v2`, and PG 18.6 bullets into short active sentences while preserving all SQLSTATEs, TPS, and latency metrics verbatim; logged `RCA-133`.
- **Result**: Verified 0 STE errors up to `## YT Cluster` (`ste_check.py --mode procedural --lang en --no-vocab`), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-151 -- Align `pg_multimaster.md` Part 1 (Overview & Empirical Limits) with ASD-STE100 (`#500`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:58Z` | Issue `#500` | `docs/issue-500-pg-multimaster-en-part1`
- **Request**: Refactor `documentation/pg_multimaster.md` overview, V1 takeaways, and Empirical Limits into <= 20-word STE sentences with 0 semicolons and update `v2.5.0` -> `v2.6.2` (V2 matrix, PG18, YT, and `v2.6.0` sections follow in the next atomic PRs to stay `< 14,800` B).
- **Changes**: Split L3, L52, Key Takeaways, and Empirical SQLSTATE Limit bullets into short STE sentences without semicolons or possessives in `documentation/pg_multimaster.md`; logged `RCA-132`.
- **Result**: Verified 0 STE errors across lines 1-106 (`ste_check.py --mode procedural --lang en --no-vocab`), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-150 -- Organize `documentation/INDEX_fr.md` into Four Diataxis Quadrants (`#498`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:53Z` | Issue `#498` | `docs/issue-498-diataxis-index-fr`
- **Request**: Reorganize `documentation/INDEX_fr.md` into the 4 Diataxis quadrants and mark English-only deep guides with `[en anglais]` while preserving STE 0 errors and valid TOC anchors.
- **Changes**: Grouped all links under `Tutoriels & Demarrage Rapide`, `Guides Pratiques`, `Reference`, and `Explication & Architecture` (`U+FE0F`-free) with synced TOC `#anchor` slugs and `[en anglais]` labels in `documentation/INDEX_fr.md`; logged `RCA-131`.
- **Result**: Verified `ste_check.py --mode mixed --lang fr --no-vocab` (0 errors, 0 warnings), 100% valid TOC anchors/links, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-149 -- Organize `documentation/INDEX.md` into Four Diataxis Quadrants (`#496`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:49Z` | Issue `#496` | `docs/issue-496-diataxis-index-en`
- **Request**: Reorganize `documentation/INDEX.md` into Tutorials/Quickstart, How-To Guides, Reference, and Explanation while maintaining STE 0 errors and valid TOC anchors.
- **Changes**: Grouped all links under the 4 Diataxis H2 sections (`U+FE0F`-free) with synced TOC anchors in `documentation/INDEX.md`; logged `RCA-130`.
- **Result**: Verified `ste_check.py --mode mixed --lang en --no-vocab` (0 errors, 0 warnings), 100% valid TOC anchors/links, Windows + WSL `unittest`, `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-148 -- Replace `INDEX.md` and `INDEX_fr.md` HTML Logo Blocks and Fix STE (`#494`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:45Z` | Issue `#494` | `docs/issue-494-diataxis-index`
- **Request**: Resolve 60-word HTML logo block STE errors in `documentation/INDEX.md` and `documentation/INDEX_fr.md`, clear remaining `-ing` warnings in `INDEX.md`, and note English-only deep guide availability in `INDEX_fr.md` (Diataxis 4-quadrant reorganization split cleanly into the next two sub-15K PRs).
- **Changes**: Converted raw `<p>` HTML logo blocks to Markdown pipe tables in `INDEX.md` and `INDEX_fr.md`, fixed `-ing` wording in `INDEX.md`, and added language note in `INDEX_fr.md`; logged `RCA-129`.
- **Result**: Verified `ste_check.py --mode mixed --no-vocab` (0 errors, 0 warnings on both files), 100% valid TOC anchors and relative links, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-147 -- Align `supported_products_fr.md` with ASD-STE100 (`#492`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:40Z` | Issue `#492` | `docs/issue-492-ste-supported-products-fr`
- **Request**: Bring `documentation/supported_products_fr.md` to 0 STE procedural errors and 0 `via`/forbidden words while preserving the French EOL H2 anchor and verified EOL data.
- **Changes**: Split semicolon-heavy PostgreSQL multi-master bullet into <= 20-word bullets, rewrote EOL intro paragraph to <= 20-word active sentences, and replaced `via` with `(Traefik)` / `avec` in `documentation/supported_products_fr.md`; logged `RCA-128`.
- **Result**: Verified `ste_check.py --mode procedural --lang fr --no-vocab documentation/supported_products_fr.md` (0 errors, 0 warnings), 0 `via`/forbidden words, intact EOL anchor, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-146 -- Align `supported_products.md` with ASD-STE100 (`#490`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:36Z` | Issue `#490` | `docs/issue-490-ste-supported-products`
- **Request**: Bring `documentation/supported_products.md` to 0 STE procedural errors and 0 `via`/forbidden words while preserving existing EOL H2 anchors and verified engine versions (`supported_products_fr.md` split to next atomic PR).
- **Changes**: Split semicolon-heavy PostgreSQL multi-master bullet into <= 20-word list items, rewrote EOL intro paragraph to active short sentences, and replaced `via` with `(Traefik)` / `with` in `documentation/supported_products.md`; logged `RCA-127`.
- **Result**: Verified `ste_check.py --mode procedural --lang en --no-vocab documentation/supported_products.md` (0 errors, 1 warning), 0 `via`/forbidden words, intact `#-decommissioned-versions-end-of-life` anchor, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-145 -- Align `tests.md` and `tests_fr.md` with ASD-STE100 and Section Parity (`#488`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:30Z` | Issue `#488` | `docs/issue-488-ste-tests-parity`
- **Request**: Bring `documentation/tests.md` and `documentation/tests_fr.md` to 0 STE procedural errors and 0 forbidden words (`via`, `ensure`, `e.g.`, `etc.`), and add missing `Rapports de Tests` and `Informations d'Architecture` sections in `tests_fr.md`.
- **Changes**: Removed passive voice (`is correctly signed by`), `via`/`Ensure/Ensures`/`e.g.` and possessives in `tests.md`; added `Rapports de Tests` and `Informations d'Architecture` sections matching `tests.md` and replaced `via`/`etc.`/`S'assure` in `tests_fr.md`; logged `RCA-126`.
- **Result**: Verified `ste_check.py --mode procedural --no-vocab` (0 errors on both EN and FR files), 0 forbidden words, intact `#00-*` anchors, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-144 -- Align `scripts.md` and `architecture.md` with ASD-STE100 and Cluster Cross-Links (`#486`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:24Z` | Issue `#486` | `docs/issue-486-ste-scripts-architecture`
- **Request**: Bring `documentation/scripts.md` (procedural mode) and `documentation/architecture.md` (mixed mode) to 0 STE errors and 0 forbidden words (`via`, `ensure`, `perform`, `e.g.`), linking shared TLS and PostgreSQL HA guides.
- **Changes**: Removed semicolons, `e.g.`, `via`, `Performs`, and passive constructions (`are automatically used by`, `have been`), added imperative caution text for `restore_physical.sh` in `scripts.md`, and added Section 6 cross-linking `tls_setup.md`, `patroni_cluster.md`, `pgpool_cluster.md`, and `pg_multimaster.md` in `architecture.md`; logged `RCA-125`.
- **Result**: Verified `ste_check.py` (0 errors on both files), 0 forbidden words, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-143 -- Align Replication and TLS Guides with ASD-STE100 (`#484`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:21Z` | Issue `#484` | `docs/issue-484-ste-repli-tls-scripts`
- **Request**: Bring `replication_setup.md`, `replication_ssl.md`, and `tls_setup.md` to 0 STE procedural errors and 0 forbidden words (`via`, `ensure`, `perform`), linking shared design context to `architecture.md` and `tls_setup.md`.
- **Changes**: Rewrote >20-word sentences, removed `e.g.` and passive voice (`are performed`, `can be encrypted`, `is encrypted by`, `can be enabled`), removed `via`/`ensure`, and cross-linked `architecture.md`/`tls_setup.md` across all 3 files; logged `RCA-124`.
- **Result**: Verified `ste_check.py --mode procedural --lang en --no-vocab` (0 errors on all 3 files), 0 forbidden words, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-142 -- Align Patroni, PgPool-II, and Galera Runbooks with ASD-STE100 (`#482`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:15Z` | Issue `#482` | `docs/issue-482-ste-cluster-runbooks`
- **Request**: Bring `patroni_cluster.md`, `pgpool_cluster.md`, and `galera_bootstrap.md` to 0 STE procedural errors and 0 forbidden words (`via`, `ensure`, `perform`), linking shared topology details to `architecture.md`.
- **Changes**: Shortened >20-word sentences, removed semicolons and passive voice (`are required`), replaced `via`/`ensure`/`perform` with active STE phrasing, and added cross-links to `architecture.md` across all 3 files; logged `RCA-123`.
- **Result**: Verified `ste_check.py --mode procedural --lang en --no-vocab` (0 errors on all 3 files), 0 forbidden words, Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-141 -- Complete 13-Section French Parity and `ATTENTION` Block in `makefile_fr.md` (`#480`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:09Z` | Issue `#480` | `docs/issue-480-makefile-fr-parity-attention`
- **Request**: Add ASD-STE100 Rule 7.1-7.3 `ATTENTION :` safety block covering `clean-data`/`clean-galera`/`clean-repli` and bring `documentation/makefile_fr.md` to 13-section parity with `documentation/makefile.md` (`0` STE errors).
- **Changes**: Added `ATTENTION :` block and missing Data Injection, Troubleshooting & Logs, Patroni, PgPool-II, InnoDB Cluster, MongoDB ReplicaSet, MySQLTuner, and PG 13-stack sections/targets to `documentation/makefile_fr.md`; logged `RCA-122`.
- **Result**: Verified `ste_check.py --mode procedural --lang fr --no-vocab documentation/makefile_fr.md` (0 errors, 0 warnings), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-140 -- Align `README_fr.md` with STE (0 Errors) and `v2.6.2` (`#478`)
- **Timestamp / Issue / Branch**: `2026-11-22T23:03Z` | Issue `#478` | `docs/issue-478-ste-readme-fr-sync`
- **Request**: Resolve STE procedural violations (`<= 20` words, 0 semicolons, 0 `via`/weak modals) and stale `v2.5.0`/`v2.6.1` tags in `README_fr.md`.
- **Changes**: Converted HTML logo/badge blocks to Markdown, shortened sentences, removed semicolons and `via`, and synced `v2.6.2` in `README_fr.md`; logged `RCA-121`.
- **Result**: Verified `ste_check.py --mode procedural --lang fr --no-vocab README_fr.md` (0 errors, 0 warnings), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-139 -- Add STE `CAUTION` Block to `makefile.md` and Sync `ROADMAP`/`README` Tags (`#476`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:58Z` | Issue `#476` | `docs/issue-476-makefile-caution-and-version-sync`
- **Request**: Replace `**DANGER**` with ASD-STE100 Rule 7.1-7.3 `CAUTION:` block in `documentation/makefile.md`, achieve 0 STE errors/forbidden words in `makefile.md`, sync `ROADMAP.md` and `README.md:215` to `v2.6.2`, and remove `via` in `README_fr.md:148,183,197`.
- **Changes**: Added `CAUTION:` block for `make clean-data`/`clean-galera`/`clean-repli` and fixed STE wording in `documentation/makefile.md`; synced `ROADMAP.md` and `README.md:215` to `v2.6.2`; updated `README_fr.md` `via` prepositions; logged `RCA-120`.
- **Result**: Verified `ste_check.py --mode procedural --lang en --no-vocab documentation/makefile.md ROADMAP.md README.md` (0 errors), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, and diff `< 14,800` B.

### ACT-138 -- Align `README.md` with ASD-STE100 (0 Errors) (`#474`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:50Z` | Issue `#474` | `docs/issue-474-ste-readme-and-version-sync`
- **Request**: Resolve STE procedural violations (`<= 20` words, 0 semicolons, active voice, 0 `may`/`ensure`/`via`) and version tags in `README.md`.
- **Changes**: Converted logo block to table, shortened sentences, removed semicolons/non-STE terms, synced `v2.6.2` on T3/CLI headings (`PG 13-stack` tag + `ROADMAP.md` split to next PR); logged `RCA-119`.
- **Result**: Verified `ste_check.py --mode procedural --lang en --no-vocab README.md` (0 errors), Windows + WSL `unittest` (73 OK, 6 skipped), `go test`, `test_config.sh`, `./mdb lint`, diff `< 14,800` B.

### ACT-137 -- Remove Unreferenced 6,190-Line `documentation/sourcery_ai_audit.md` (`#472`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:44Z` | Issue `#472` | `docs/issue-472-remove-sourcery-audit-log`
- **Request**: Fix documentation audit finding #8 by deleting the unreferenced 6,190-line (-374 KB) `documentation/sourcery_ai_audit.md` bot log and documenting the single-file deletion exception to the 15K PR diff limit.
- **Changes**: Removed `documentation/sourcery_ai_audit.md` via `git rm` (-6,190 lines, 0 repo links remaining after PR `#471`); logged `APP-031` in `docs/RCA_REGISTER.md`.
- **Result**: Verified 0 dangling references, `non_ascii_added` = 0 in governance, Windows + WSL `-W error::ResourceWarning` `unittest` (73 tests OK, 6 skipped), `go test -count=1 ./...`, `tests/test_config.sh`, and `./mdb lint`.

### ACT-136 -- Repair 9 Broken GFM Anchors and Move `tests*.md` H2 Icons (`#470`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:40Z` | Issue `#470` | `docs/issue-470-fix-gfm-anchors`
- **Request**: Fix all 9 broken GFM anchors (`README.md:128`, `README_fr.md:129`, `architecture.md:128`, `makefile.md:89`, `makefile_fr.md:51`, `INDEX.md:22,23,92`, `INDEX_fr.md:71`), remove raw `<img>` tags from `tests.md`/`tests_fr.md` H2 titles, and drop the `sourcery_ai_audit.md` index link prior to M3 deletion.
- **Changes**: Moved 4 engine icons below H2 headings in `documentation/tests.md` and `tests_fr.md`; stripped `U+FE0F` selectors and removed `sourcery_ai_audit.md` row in `documentation/INDEX.md`; updated all 9 `#anchor` targets to exact GFM slugs; logged `RCA-118`.
- **Result**: Verified 0 broken relative links/anchors, Windows + WSL `-W error::ResourceWarning` `unittest` (73 tests OK, 6 skipped), `go test -count=1 ./...`, `tests/test_config.sh`, `./mdb lint`, and diff `< 14,800` B.

### ACT-135 -- Remove Stale Audit/Plan Docs, Clean `tests/README.md`, and Fix `ACT-001` Link (`#468`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:34Z` | Issue `#468` | `docs/issue-468-fix-stale-docs-and-gfm-anchors`
- **Request**: Fix audit #2/#9 stale file and path items: delete `audit_report.md` and `INTEGRAL_TEST_PLAN.md`, clean `tests/README.md`, and fix `ACT-001` `.agents/rules/` link (9 GFM anchors split to next PR).
- **Changes**: Deleted `documentation/audit_report.md` and `documentation/INTEGRAL_TEST_PLAN.md`; dropped `test_perf_threads.sh` and updated `tests/README.md` for multi-DB suites; fixed `ACT-001` link (`../.agents/AGENTS.md`); logged `RCA-117`.
- **Result**: Verified Windows + WSL `-W error::ResourceWarning` `unittest` (73 tests OK, 6 skipped), `go test -count=1 ./...`, `tests/test_config.sh`, `./mdb lint`, and diff `< 14,800` B.

### ACT-134 -- Fix `.agent/` Links, Nonexistent Targets/Scripts, and Version/CLI Drift (`#466`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:27Z` | Issue `#466` | `docs/issue-466-fix-agent-links-and-rules-drift`
- **Request**: Fix documentation audit findings #1, #3, #4, and #7: replace `file://` local URI links in `.agent/workflows/doc-sync.md`, remove nonexistent targets/scripts in workflows/rules, and align `./mdb` + active DBMS versions in `.agent/rules/` and `AGENTS.md`.
- **Changes**: Rewrote `.agent/workflows/doc-sync.md` links to verified relative `../../` paths; updated `.agent/workflows/maintenance.md` (`make clean-reports`, `./mdb down`), `.agent/workflows/architecture-audit.md`, `.agent/rules/02_architecture.md` (multi-engine catalog, `./mdb doctor`), `.agent/rules/03_execution_rules.md` (`./mdb` primary CLI), and `AGENTS.md` (active LTS/supported versions); logged `RCA-116`.
- **Result**: Verified zero `file://` links, Windows + WSL `-W error::ResourceWarning` `unittest` (73 tests OK, 6 skipped), `go test -count=1 ./...`, `tests/test_config.sh`, `./mdb lint`, and diff `< 14,800` B.

### ACT-133 -- Remove Duplicate Root Rule Files and Align Governance Test Paths (`#464`)
- **Timestamp / Issue / Branch**: `2026-11-22T22:22Z` | Issue `#464` | `docs/issue-464-fix-doc-links-rules-dedup`
- **Request**: Fix documentation audit duplicate-rule finding: remove root `03_execution_rules.md` and `04_best_practices.md` duplicating `.agent/rules/`, and update `tests/test_project_governance_rules.py` to check `.agent/rules/`.
- **Changes**: Removed root `03_execution_rules.md` and `04_best_practices.md`; updated `tests/test_project_governance_rules.py` lines 21-30 to point `exec_rule_md` and `bp_rule_md` to `.agent/rules/`; updated historical `ACT-001` references to avoid dead root links; logged `RCA-115`.
- **Result**: Verified Windows + WSL `-W error::ResourceWarning` `unittest` (73 tests, 6 skipped), `go test -count=1 ./...` (11 packages), `tests/test_config.sh`, `./mdb lint`, and diff `< 14,800` B.

### ACT-132 -- Release `v2.6.2`: PG Audit Hardening, Deduplication & Test Parity (`#462`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:54Z` | Issue `#462` | `chore/issue-462-release-v2.6.2`
- **Request**: Bump project version to `v2.6.2` across `VERSION`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, and `Changelog` (`<= 600` lines FIFO), update governance registers, and push tag `v2.6.2` once merged.
- **Changes**: Updated `VERSION`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, and `Changelog` (FIFO trimmed oldest `1.0.8`-`1.0.14` entries to keep `<= 600` lines); logged `RCA-114`.
- **Result**: Verified `release_notes.py --tag v2.6.2 --check`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, `mdb lint`, and diff `< 14,800` B.

### ACT-131 -- Expand Unit Tests for All Runners, `pb_run`, `reset_ds`, `YT_RETRY_PY` & PG18 (`#460`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:47Z` | Issue `#460` | `test/issue-460-pg-libs-runner-coverage`
- **Request**: Expand `tests/test_pg_libs.py` across `.env`/`BENCH_OUT_DIR` handling on all 6 runners, `pb_run`/`pb_run_opt` crash/sampling-rate detection, `wcnt`/`wait_sub_ready`/`wait_wal_replay` timeouts, bidirectional `reset_ds`/`reset_ds_opt`, missing-file V2 CSV upsert, `YT_RETRY_PY` socket-drop recovery, and PG 18 sysbench/netem wrappers (`#191.16` part 2).
- **Changes**: Added unit tests across `TestBenchPgLib`, `TestBenchPgV2Lib`, `TestBenchPgOptimizedLib`, and `TestBenchPg18Lib` in `tests/test_pg_libs.py`; logged `RCA-113`.
- **Result**: Verified Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-130 -- Expand Static Guard for HAProxy L7/Resolvers & Compose Health Parity (`#458`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:43Z` | Issue `#458` | `test/issue-458-static-haproxy-compose-parity`
- **Request**: Extend `tests/test_repo_static.py` to cover all 5 `scripts/*/haproxy.cfg` L7/resolver rules, Compose HAProxy/`:8404` healthchecks, `yb_node3` & `crdb_node1..3` readiness healthchecks, `15459:8404` on `haproxy_pgedge`, and Citus/YT `DB_ROOT_PASSWORD`-first order (`#191.16` part 1).
- **Changes**: Expanded `test_pg_compose_durable_tunings_and_haproxy_ram_caps` in `tests/test_repo_static.py`; logged `RCA-112`.
- **Result**: Verified Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-129 -- Add HAProxy Docker Resolvers, L7 Checks & Compose Healthchecks (`#456`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:38Z` | Issue `#456` | `fix/issue-456-haproxy-resolvers-compose-health`
- **Request**: Add `resolvers docker` + `init-addr last,libc,none resolvers docker` + `option pgsql-check` across `pg_birep`, `pg18_birep`, `pgedge`, and `yugabyte` `haproxy.cfg` (`#191.12`); add `yb_node3`, `crdb_node1..3`, and all 5 HAProxy `healthcheck`s plus `127.0.0.1:15459:8404` on `haproxy_pgedge` (`#191.18`).
- **Changes**: Updated `scripts/{pg_birep,pg18_birep,pgedge,yugabyte}/haproxy.cfg` and `docker-compose-{yugabyte,cockroach,pgedge,pg-birep,pg18-birep}.yml`; logged `RCA-111`.
- **Result**: Verified `haproxy -c -f` on all 5 configs, `docker compose config -q`, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-128 -- Parameterize Shared PG 17/18 Bidirectional Setup (`#454`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:25Z` | Issue `#454` | `refactor/issue-454-parameterize-pg-birep`
- **Request**: Deduplicate PG 17 and PG 18 bidirectional logical replication setup scripts via shared `scripts/pg_common/setup_birep.sh` while preserving CLI paths (`#191.20` part 3c).
- **Changes**: Added `scripts/pg_common/setup_birep.sh` backed by `lib.sh` (`wait_pg_nodes`, `esc_conn_val`) and converted `scripts/pg_birep/setup_birep.sh` + `scripts/pg18_birep/setup_pg18_birep.sh` into thin wrappers; logged `RCA-110`.
- **Result**: Verified `bash -n`, mock-docker smoke test, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-127 -- Parameterize Shared PG 17/18 Logical Replication Setup (`#451`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:22Z` | Issue `#451` | `refactor/issue-451-parameterize-pg-logical`
- **Request**: Deduplicate PG 17 and PG 18 uni-directional logical replication setup scripts via shared `scripts/pg_common/setup_logical.sh` while preserving CLI paths (`#191.20` part 3b).
- **Changes**: Added `scripts/pg_common/setup_logical.sh` using `lib.sh` (`wait_pg_nodes`, `esc_conn_val`) and converted `scripts/pg_logical/setup_pg_logical.sh` + `scripts/pg18_logical/setup_pg18_logical.sh` to thin wrappers; logged `RCA-109`.
- **Result**: Verified `bash -n`, mock-docker smoke test, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-126 -- Harden `mdb inject`, Client Inference & Markers (`#416`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:18Z` | `#416` | `fix/issue-416-mdb-ops-reliability`
- **Request**: Mock `streamCommand`, bound `runInjectCmd`, fix `mysql_node1`, wire hosts/`DefaultDB`, `shortcut:` & tests.
- **Changes**: `cmd/mdb/*.go`, `{interactive_runner,mysql_docker}.py`, `Changelog`, `RCA-108`.
- **Result**: `go test` 11/11, `go vet`, `mdb lint`, `unittest` 61/67, `release_notes.py` OK.

### ACT-125 -- Extract Shared PG Setup Helpers & Parameterize PG 17/18 Streaming (`#449`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:13Z` | Issue `#449` | `refactor/issue-449-parameterize-pg-setup`
- **Request**: Deduplicate PG 17 and PG 18 physical streaming setup scripts via shared parameterized helpers while preserving existing script entry paths (`#191.20` part 3a).
- **Changes**: Added `scripts/pg_common/lib.sh` (`run_sql`, `wait_pg_nodes`, `esc_conn_val`) and `scripts/pg_common/setup_streaming.sh`; converted `scripts/pg_streaming/setup_pg_streaming.sh` and `scripts/pg18_streaming/setup_pg18_streaming.sh` to thin wrappers; logged `RCA-107`.
- **Result**: Verified `bash -n`, mock-docker smoke test, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-124 -- Replace Fixed `/tmp/*.out` Test Logs with `mktemp` & `EXIT` Traps (`#447`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:09Z` | Issue `#447` | `fix/issue-447-mktemp-pg-test-logs`
- **Request**: Replace fixed host `/tmp/*.out` paths with `mktemp` + `EXIT` trap cleanup across `tests/test_{pg_birep,bucardo,pg_logical,pg18_logical,pgedge,pg_streaming,pg18_streaming}.sh` (`#191.20` part 2).
- **Changes**: Replaced `/tmp/{lb,lbuc,ll,ll18,ls,pg_sync_stall,pg18_sync_stall}.out` with `mktemp` + `trap 'rm -f ...' EXIT` across all 7 test scripts; logged `RCA-106`.
- **Result**: Verified `bash -n`, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-123 -- Recover `sub_from_node2` in `test_pg18_birep.sh`, Sync `v25.4` Labels & Citus/YT Auth Order (`#445`)
- **Timestamp / Issue / Branch**: `2026-11-22T02:04Z` | Issue `#445` | `fix/issue-445-birep-sub-mktemp-labels`
- **Request**: Recover and verify `sub_from_node2` worker `= 1` after `9102` and `9201` in `test_pg18_birep.sh` (`#191.10`), use `mktemp` + `trap` in `test_pg18_birep.sh`, update stale `v24.3.0` labels to `v25.4` in `test_cockroach.sh` and `test_pg_extended_matrix.sh` (`#191.20`), and align `DB_ROOT_PASSWORD`-first order in `test_citus.sh` and `test_yt_cluster.sh` (`#191.17`).
- **Changes**: Updated `tests/test_pg18_birep.sh`, `tests/test_cockroach.sh`, `tests/test_citus.sh`, `tests/test_yt_cluster.sh`, and `scripts/test_pg_extended_matrix.sh`; logged `RCA-105`.
- **Result**: Verified `bash -n`, `test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-122 -- Harden Setup Creds, Fail on YB/CRDB Quorum Timeout & Fix `test_pgpool`/`test_config` (`#443`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:58Z` | Issue `#443` | `fix/issue-443-setup-quorum-pgpool-tests`
- **Request**: Harden Bucardo/PgPool credential passing and `/root/.bucardorc` mode `600`, fail on CockroachDB/YugabyteDB quorum timeouts, use `mktemp` + `v25.4` in `setup_cockroach.sh`, inspect PgPool network dynamically + `curl --max-time 5`, and avoid `+x` mutations in `tests/test_config.sh`.
- **Changes**: Updated `scripts/bucardo/setup_bucardo.sh`, `scripts/pgpool/setup_replication.sh`, `scripts/cockroach/setup_cockroach.sh`, `scripts/yugabyte/setup_yugabyte.sh`, `tests/test_pgpool.sh`, and `tests/test_config.sh`; logged `RCA-104`.
- **Result**: Verified `bash -n`, `test_config.sh`, Windows + WSL Python `unittest`, `go test -count=1 ./...`, and diff `< 14,800` B.

### ACT-121 -- Deduplicate `mdb` Container and Setup Lookups via Catalog (`#433`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:54Z` | Issue `#433` | `refactor/issue-433-mdb-catalog-ssot-dedup`
- **Request**: Read `defaultContainer` and `mongo8` setup/test metadata from `pkg/catalog`, delegate `resolveEnvContainer` to `client.ResolveContainer`, and delete `pickContainerName`/`resolveContainer` (Slice 4C of `#415` -> `#432` -> `#433`).
- **Changes**: Updated `cmd/mdb/main.go`, `cmd/mdb/commands_ops.go`, `cmd/mdb/commands_lint.go`, `cmd/mdb/main_test.go`, and `RCA-103`.
- **Result**: `go test -count=1 ./...` (`11/11`), `go vet ./...`, `go run ./cmd/mdb lint` (`70` shell scripts + `21` Compose files), `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped) pass; PR diff `< 15,000` chars.

### ACT-120 -- Bound Standby `pg_basebackup` Retries, Escape `conninfo` & Fix `DB_ROOT_PASSWORD` Order (`#440`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:49Z` | Issue `#440` | `fix/issue-440-standby-retries-creds-precedence`
- **Request**: Escape `primary_conninfo` credentials, move `rm -rf` inside bounded 30-attempt `pg_basebackup` loops, and standardize `${DB_ROOT_PASSWORD:-${PG_LAB_PASSWORD:-pg_poc_ephemeral}}` order.
- **Changes**: Updated `docker-compose-{pg17-baseline,pg-streaming,pg18-streaming,citus,yt-cluster}.yml`, `scripts/citus/setup_citus.sh`, and `scripts/yt_cluster/setup_yt_cluster.sh`; logged `RCA-102`.
- **Result**: Verified `docker compose config -q`, `bash -n`, live `esc_lp`/`esc_guc` conninfo auth, Win/WSL `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-119 -- Consume Catalog Setup SSOT in Topology & Remove Dead `SysbenchRunner` (`#432`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:44Z` | Issue `#432` | `refactor/issue-432-topology-catalog-bench-cleanup`
- **Request**: Read setup SSOT from `catalog.DefaultCatalog()`, use `client.ResolveContainer` in `pkg/topology`, and delete dead `SysbenchRunner`/`CommandExecutor` code in `pkg/bench` (Slice 4B of `#415` -> `#432` -> `#433`).
- **Changes**: Updated `pkg/topology/topology.go`, `pkg/topology/galera.go`, `pkg/bench/sysbench.go`, `pkg/bench/sysbench_test.go`, and `RCA-101`.
- **Result**: `go test -count=1 ./...` (`11/11`), `go vet ./...`, `go run ./cmd/mdb lint` (`70` shell scripts + `21` Compose files), `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped) pass; PR diff `< 14,500` chars.

### ACT-118 -- Harden PG 18 `sysbench` Quoting/Drain & Consolidate Shared Helpers (`#437`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:40Z` | Issue `#437` | `fix/issue-437-pg18-lib-drain-dedup`
- **Request**: Consolidate `assert_zero_pg18_containers`, `_ref`, `conv_chk_pg18`, `_drop_sb_sub`, `_tc`, and `run_wan_netem_pg18` in `bench_pg18_lib.py`, rely on `reset_ds` for `pg18-birep` pre-drain/reset, quote PG18 `sysbench` passwords via `PGPASSWORD`, and enforce `wait_sub_ready` + `wait_wal_replay`.
- **Changes**: Updated `scripts/bench_pg18_lib.py`; logged `RCA-100`.
- **Result**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-117 -- Consolidate `run_wan_netem`, Quote V2 `sysbench` & Enforce WAL Drain (`#434`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:36Z` | Issue `#434` | `fix/issue-434-v2-pg18-drain-dedup`
- **Request**: Consolidate `run_wan_netem`, `drop_sb_sub`, `ref_sub`, and `assert_zero_containers`; pass V2 sysbench `pw` via `PGPASSWORD` + `shlex.quote` and enforce WAL replay drain + `srsubstate='r'` timeout.
- **Changes**: Added `run_wan_netem` to `bench_pg_lib.py`; updated `bench_pg_opt_workloads.py` and `bench_pg_v2_lib.py`; logged `RCA-099`.
- **Result**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-116 -- Add Catalog `SetupArgs`/`SetupEnv`/`DefaultDB` SSOT Fields & Wire `ResolveContainer` in `interactive` (`#415`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:33Z` | Issue `#415` | `refactor/issue-415-catalog-ssot-dead-code`
- **Request**: Consolidate `DefaultDB`, `SetupArgs`, and `SetupEnv` into `pkg/catalog` as SSOT and replace inline `client.PS` resolution in `pkg/interactive/steps.go` with `client.ResolveContainer` (Slice 4A of 3-PR split `#415` -> `#432` -> `#433` to stay `< 15,000` diff bytes).
- **Changes**: Updated `pkg/catalog/catalog.go` (`DefaultDB`, `SetupArgs`, `SetupEnv` fields, `cloneEnv` defensive copies, `mongo8` `SetupArgs`/`SetupEnv`, `DefaultDB: "labdb"` on the 10 PG clusters defaulting `POSTGRES_DB=${PG_DB:-labdb}`), `pkg/catalog/catalog_test.go`, `pkg/interactive/steps.go` (`VerifyEnvironment` via `client.ResolveContainer`), and `RCA-098`.
- **Result**: `go test -count=1 ./...` (`11/11` packages PASS), `go vet ./...` (PASS), `go run ./cmd/mdb lint` (`70` scripts + `21` Compose files PASS), `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped in `test_lab.py`), and PR diff `< 15,000` bytes.

### ACT-115 -- Drain WAL Replay, Reset Opt Bi-Dir Peers & Quote Sysbench Passwords (`#428`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:28Z` | Issue `#428` | `fix/issue-428-opt-workloads-drain-reset`
- **Request**: Poll `pg_stat_replication` before `_drop_sb_sub` and fail on `srsubstate='r'` timeout, drain/reset `pg-birep`/`pg18-birep` in `reset_ds_opt`, and quote `sysbench` passwords via `PGPASSWORD`.
- **Changes**: Added `wait_wal_replay`, `wait_sub_ready`, and `drop_sb_sub` to `scripts/bench_pg_lib.py` and updated `scripts/bench_pg_opt_workloads.py`; logged `RCA-097`.
- **Result**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-114 -- Parameterize Patroni HAProxy Stats Auth & Harden `generate_certs.sh` (`#414`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:24Z` | Issue `#414` | `fix/issue-414-patroni-haproxy-certs`
- **Request**: Replace hardcoded `admin:adminpass` in Patroni HAProxy stats configuration and tests with `HAPROXY_STATS_AUTH`, document it in `.env.example`, and harden variable quoting and `755` directory permissions in `scripts/patroni/generate_certs.sh` with static regression checks.
- **Changes**: Updated `conf/haproxy-patroni.cfg` (`stats auth "$HAPROXY_STATS_AUTH"`), `docker-compose-patroni.yml` (`HAPROXY_STATS_AUTH=${HAPROXY_STATS_AUTH:-admin:adminpass}`), `tests/test_patroni.sh` (`-u "${HAPROXY_STATS_AUTH:-admin:adminpass}"`), and `.env.example` (`# HAPROXY_STATS_AUTH=admin:adminpass`); quoted all `$CERT_DIR`, `$name`, `$cn`, and `$1` references and aligned `chmod 755 "$CERT_DIR"` (`600` on `*.key`/`haproxy.pem`) in `scripts/patroni/generate_certs.sh`; extended `test_patroni_self_contained_dockerfiles_and_mtls` in `tests/test_repo_static.py`; logged `RCA-096`.
- **Result**: Verified live `haproxy -c -V` and live HTTPS Basic Auth (`200` valid / `401` invalid) in `patroni-rhel8-haproxy:latest` (HAProxy 3.4.8), live `generate_certs.sh` with spaces in `CERT_DIR` (`755`/`600`/`644`), `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped in `test_lab.py`), `go test -count=1 ./...` (`11/11` packages), `go run ./cmd/mdb lint` (`70` scripts, `21` compose files), and PR diff `< 15,000` chars.

### ACT-113 -- Close V2 Runner Log Handle via `with` & Add PG 18 / `ResourceWarning` Tests (`#413`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:21Z` | Issue `#413` | `fix/issue-413-python-file-leaks`
- **Request**: Replace remaining unclosed `.open(...)` handles in benchmark runners with context managers and add unit, `ResourceWarning`, and static `.open(` regression tests in `tests/test_pg_libs.py`.
- **Changes**: Updated `scripts/bench_pg_v2_runner.sh` to wrap `run_topo(topo, logf)` in `with ((LOGD / f"{topo}.log").open(...) if topo in NEW_CORE else nullcontext()) as logf:` (removing manual `logf.close()`; `bench_pg_multimaster.sh`, `bench_pg_v2_lib.py`, `bench_pg18_lib.py`, and `bench_yt_runner.sh` were already resolved on `main` via PRs #419/#421/#423); added `TestBenchPg18Lib` and `TestBenchResourceHygiene` to `tests/test_pg_libs.py`; logged `RCA-095`.
- **Result**: Verified `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` live-DB skipped in `test_lab.py`), `go test -count=1 ./...` (`11/11` packages PASS), `go run ./cmd/mdb lint` (`70` scripts + `21` compose files OK), and PR diff `< 15,000` chars.

### ACT-112 -- Compose Env via `RunWithEnv` & `Client.ResolveContainer` (`#412`)
- **Timestamp / Issue / Branch**: `2026-11-21T23:40Z` | `#412` | `refactor/issue-412-compose-env-resolve`
- **Request**: Pass Compose env via `RunWithEnv`, add `wsl`/`wsl.exe` to `WSLENV`, add `ResolveContainer`.
- **Changes**: `compose.go` (`runCompose`), `client.go` (`wsl`/`wsl.exe`, `ResolveContainer`, drop `extractComposeEnv`), tests, `RCA-094`.
- **Result**: `go test ./...` (11/11), `go vet`, `mdb lint` (70 scripts, 21 compose) pass.

### ACT-111 -- Deduplicate `pb_run_opt`, `conv_chk_opt`, Container Checks & Pre-Drain `pg18-birep` (`#426`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:12Z` | Issue `#426` | `fix/issue-426-opt-common-dedup`
- **Request**: Remove duplicate `pb_run_opt`, `conv_chk_opt`, `assert_zero_opt_containers`, and `ref_sub` logic in `scripts/bench_pg_opt_common.py`, add shared `tc_netem` in `scripts/bench_pg_lib.py`, and cover `pg18-birep` pre-drain/reset in `reset_ds`.
- **Changes**: Added `assert_zero_containers`, `tc_netem`, `ref_sub`, parameterized `conv_chk`, and `pg18-birep` `reset_ds` drain/reset to `scripts/bench_pg_lib.py`; delegated `scripts/bench_pg_opt_common.py`; logged `RCA-093`.
- **Result**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-110 -- Fail on Crashed `pgbench`, Drain/Reset `pg-birep` & Quote `run_sb` (`#424`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:08Z` | Issue `#424` | `fix/issue-424-pb-exit-checks-birep-reset-drain`
- **Request**: Capture `pgbench` exit codes and abort strings instead of `||true`, lower `C_multinode_ro` logging with `--sampling-rate=0.05` and clean `/tmp/pb_*`, drain/reset `pg-birep` in `reset_ds`, and quote `run_sb` password via `PGPASSWORD`.
- **Changes**: Updated `scripts/bench_pg_lib.py` (`pb_run`, `reset_ds`, `run_sb`); logged `RCA-092`.
- **Result**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-109 -- Deduplicate `YT_RETRY_PY`/CSV Helpers, Close YT Handle & Quote YT `sysbench` Password (`#422`)
- **Timestamp / Issue / Branch**: `2026-11-22T01:02Z` | Issue `#422` | `fix/issue-422-yt-opt-retry-csv-dedup`
- **Request**: Deduplicate `YT_RETRY_PY`, `wcnt_opt`, and CSV writers across `bench_yt_runner.sh` and `bench_pg_opt_common.py`, quote YT `sysbench` password via `PGPASSWORD`, close YT resume handle, and write YT CSV atomically.
- **Changes**: Updated `scripts/bench_yt_runner.sh` and `scripts/bench_pg_opt_common.py` to reuse `YT_RETRY_PY`, `write_csv_atomic`, `upsert_csv`, and `wcnt` from `scripts/bench_pg_lib.py`; logged `RCA-091`.
- **Result**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, `bash -n`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-108 -- Missing V2 CSV Header, Atomic Closed CSV I/O, `wcnt` Timeout & `YT_RETRY_PY` Hardening (`#420`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:58Z` | Issue `#420` | `fix/issue-420-csv-atomic-wcnt-yt-retry`
- **Request**: Fix missing CSV `FileNotFoundError` in `append_summary_preserving`, close/atomize CSV I/O in V2/PG18 libs, raise `RuntimeError` on `wcnt` timeout, and add shared `YT_RETRY_PY` (kwargs connect + guarded `rollback()`/reconnect) and `write_csv_atomic`/`upsert_csv` to `scripts/bench_pg_lib.py`.
- **Changes**: Updated `scripts/bench_pg_lib.py`, `scripts/bench_pg_v2_lib.py`, and `scripts/bench_pg18_lib.py`; logged `RCA-090`.
- **Result**: Verified Windows + WSL Python `unittest` (`0` ResourceWarnings), `go test -count=1 ./...`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-107 -- Benchmark Runner `.env` Sourcing, `BENCH_OUT_DIR` Parity & Windows Temp Fix (`#418`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:54Z` | Issue `#418` | `fix/issue-418-bench-env-csv-retry`
- **Request**: Fix `.env` sourcing across V1/V2/PG18/YT/extended runners, honor `BENCH_OUT_DIR` in V1 and optimized runners, close/atomize V1 CSV I/O, and fix Windows `TemporaryDirectory` cleanup error.
- **Changes**: Updated `scripts/bench_pg_multimaster.sh` (`.env` sourcing, remove `--env-file .env.example`, `BENCH_OUT_DIR`, closed read + atomic `.csv.tmp` rename), `scripts/bench_pg_{v2_runner,pg18_runner,optimized_runner}.sh`, `scripts/bench_yt_runner.sh`, `scripts/test_pg_extended_matrix.sh`, and `tests/test_pg_libs.py` (`ignore_cleanup_errors=True`); logged `RCA-089`.
- **Result**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, `bash -n`, `tests/test_config.sh`, and diff `< 14,800` B.

### ACT-106 -- Sync EN/FR Supported Products Matrices & `Changelog` FIFO for Phase 16 (`#410`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:11Z` | Issue `#410` | `docs/issue-410-products-changelog`
- **Request**: Update `documentation/supported_products{,_fr}.md` for self-contained Patroni Dockerfiles, pinned `etcd:v3.5.17` / `PgPool 4.4.3`, 31-image E2E inventory, and 31/31 live E2E coverage, and update `Changelog` synced with `VERSION` (`2.6.1`) within `<= 600` lines FIFO.
- **Changes**: Updated `documentation/supported_products.md`, `documentation/supported_products_fr.md`, `Changelog` (597 lines FIFO, trimmed `1.0.7`, prioritized `feat:`/`fix:`/`doc:`/`test:` under `2.6.1`), and `docs/ACTION_LOGBOOK.md` (`ACT-106`).
- **Result**: Completes Phase 16 across merged PRs `#398` (`#397`), `#400` (`#396`), `#403` (`#399`), `#404` (`#401`), `#405` (`#402`), `#407` (`#406`), and `#409` (`#408`): `31/31` E2E images PRESENT (`7` custom + `24` upstream) and `31/31` active topologies verified live E2E; verified `go test -count=1 ./...`, `mdb lint`, `mdb images check`, `release_notes.py --tag v2.6.1 --check`, and Python tests.

### ACT-105 -- Update Patroni Cluster Guide & Close Missing-Image Gap in RCA Register (`#408`)
- **Timestamp / Issue / Branch**: `2026-11-22T00:06Z` | Issue `#408` | `docs/issue-408-patroni-guide-rca`
- **Request**: Update `documentation/patroni_cluster.md` for self-contained non-root Patroni Dockerfiles, mTLS HAProxy, and 11-group/14-assertion E2E coverage, and update `docs/RCA_REGISTER.md` to close the external Patroni image gap and record the 31-image E2E architecture.
- **Changes**: Updated `documentation/patroni_cluster.md` (Dockerfile matrix, `./mdb up patroni`/`./mdb images build patroni`, HTTPS stats `7000`, mTLS REST `8008`, `DB_ROOT_PASSWORD:-rootpass`, 11 test groups + `test_failover.sh`), `docs/RCA_REGISTER.md` (`APP-018`, `IMP-017`, `APP-030`), and `docs/ACTION_LOGBOOK.md` (`ACT-105`).
- **Result**: Verified `go test -count=1 ./...` (11/11), `mdb lint` (70 scripts + 21 compose files), `mdb images check` (31/31 PRESENT), Python governance/static/unit suite, and diff `< 15,000` B.

### ACT-104 -- Document `mdb images` CLI, Self-Contained Patroni & 31/31 E2E Status in EN/FR READMEs (`#406`)
- **Timestamp / Issue / Branch**: `2026-11-21T23:57Z` | Issue `#406` | `docs/issue-406-images-patroni-docs`
- **Request**: Document `./mdb images list|build|pull|check` (and `Makefile` wrappers `build-images`/`pull-images`/`check-images`), self-contained Patroni Dockerfiles, and 31/31 live E2E coverage in `README.md` and `README_fr.md`.
- **Changes**: Updated `README.md`, `README_fr.md` (Verification Status table, General Commands table, thin `Makefile` wrappers note, and self-contained Patroni ports/Dockerfiles note), and `docs/ACTION_LOGBOOK.md` (Phase 16 + `ACT-104`).
- **Result**: Consolidates merged PRs `#398` (`#397`), `#400` (`#396`), `#403` (`#399`), `#404` (`#401`), and `#405` (`#402`) (`31/31` E2E images PRESENT: `7` custom incl. Patroni `131MB`/`513MB`/`117MB` + `24` upstream; `31/31` active topologies live E2E PASS); verified `go test -count=1 ./...`, `python -m unittest discover -s tests -v`, `mdb lint`, and `mdb images check`.

### ACT-103 -- Patroni 4.x Verifier (`streaming`/`Primary`), E2E Suites & Static Tests (`#402`)
- **Timestamp / Issue / Branch**: `2026-11-21T22:49Z` | Issue `#402` | `fix/issue-402-patroni-verifier-tests`
- **Request**: Support Patroni 3.x/4.x `streaming` and `Primary` states in `PostgresVerifier`, fix live E2E bugs in `tests/test_patroni.sh` and `tests/test_failover.sh`, and add static regression coverage in `tests/test_repo_static.py`.
- **Changes**: Extended `pkg/dbclient/postgres.go` (`verifyPatroni`) and `pkg/dbclient/postgres_mongo_test.go`; updated `tests/test_patroni.sh` (dynamic `PATRONI_NET`, `PGPASSWORD`, `Leader|Primary`, POSIX `awk` version check, HTTPS stats `https://127.0.0.1:7000/`) and `tests/test_failover.sh`; added `test_patroni_self_contained_dockerfiles_and_mtls` in `tests/test_repo_static.py`; logged `RCA-088`.
- **Result**: Verified live Patroni E2E (`mdb test patroni` HEALTHY `3/3`, `--suite` `14/14`, `test_failover.sh patroni` `1/1`, `mdb client patroni` PG `17.12`, `mdb down patroni` 0 leftovers), `go test -count=1 ./...` (11/11), `mdb lint`, and static Python tests.

### ACT-102 -- Patroni Compose `build:`/`service_healthy` Wiring & HAProxy mTLS Checks (`#401`)
- **Timestamp / Issue / Branch**: `2026-11-21T22:38Z` | Issue `#401` | `feat/issue-401-patroni-compose-mtls`
- **Request**: Wire `build:` sections, `DB_ROOT_PASSWORD:-rootpass` parity, and `service_healthy` startup ordering into `docker-compose-patroni.yml`, and enable true mTLS health checks + Docker DNS resolution in `conf/haproxy-patroni.cfg`.
- **Changes**: Added `build:` blocks and `condition: service_healthy` dependencies (`etcd1..3` -> `node1..3` -> `haproxy`) plus `rootpass` default in `docker-compose-patroni.yml`; updated `conf/haproxy-patroni.cfg` with stdout logging, `resolvers docker` (`127.0.0.11:53`), symmetric 3-node backends, and mTLS checks (`crt /certs/haproxy.pem ca-file /certs/ca.crt verify required`); logged `RCA-087`.
- **Result**: Verified live `docker compose -f docker-compose-patroni.yml build`, `mdb up patroni` (7/7 healthy, HAProxy Layer7 mTLS 200 OK in 4-7ms, 0 ECONNREFUSED alerts), `go test -count=1 ./...`, and `mdb lint`.

### ACT-101 -- `mdb images` CLI (`list|build|pull|check`) & Thin `Makefile` Wrappers (`#399`)
- **Timestamp / Issue / Branch**: `2026-11-21T23:22Z` | Issue `#399` | `feat/issue-399-mdb-images-cli`
- **Request**: Implement `mdb images` (`list [--json]`, `build`, `pull`, `check`), thin `Makefile` wrappers (`build-images`, `pull-images`, `check-images`), and 21-compose parity tests covering all 31 E2E images.
- **Changes**: Added `cmd/mdb/commands_images{,_test}.go`, wired `images` in `cmd/mdb/{main,commands_lifecycle}.go`, and added thin wrappers in `Makefile`.
- **Result**: Verified `go test -count=1 ./...` (11/11), `python -m unittest discover -s tests -v`, `mdb lint`, `mdb images check` (31/31 PRESENT), and diff `< 15,000` B.

### ACT-100 -- Self-Contained Patroni Dockerfiles, Config, Supervisor & Entrypoint (`#396`)
- **Timestamp / Issue / Branch**: `2026-11-21T22:25Z` | Issue `#396` | `feat/issue-396-patroni-dockerfiles`
- **Request**: Author missing Patroni Dockerfiles (`etcd`, `postgresql`, `haproxy`), `conf/patroni.yml`, non-root supervisor config, and non-root entrypoint support.
- **Changes**: Added `scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}` (pinned bases, non-root `USER`, 0 HIGH/WARN/INFO lint, 0 baked secrets/SSH keys) and `conf/patroni.yml`; updated `conf/supervisord-patroni.conf`, `scripts/patroni/entrypoint_node.sh`, and `docs/RCA_REGISTER.md` (`RCA-086`).
- **Result**: Built `patroni-rhel8-etcd:latest` (`130MB`), `patroni-rhel8-postgresql:latest` (`513MB`), and `patroni-rhel8-haproxy:latest` (`117MB`); verified `go test -count=1 ./...`, `unittest`, `mdb lint`, and `lint_dockerfile.py`.

### ACT-099 -- Reproducible `scripts/Dockerfile.bench`, Docker Image APIs & Patroni Auto-Build (`#397`)
- **Timestamp / Issue / Branch**: `2026-11-21T23:16Z` | Issue `#397` | `feat/issue-397-mdb-images-cli`
- **Request**: Add reproducible `scripts/Dockerfile.bench` for `multi-db-pgbench-sysbench:latest`, extend `pkg/docker` with `BuildImageFile`/`PullImage`/`ListLocalImages`, and add Patroni image auto-build in `pkg/topology/patroni.go`.
- **Changes**: Added `scripts/Dockerfile.bench` (non-root `USER postgres` + `setcap cap_net_admin+ep` on `tc`), `pkg/docker/client.go` + `docker_test.go`, `pkg/topology/{galera,patroni,topology_test}.go`, and `APP-029` in `docs/RCA_REGISTER.md`.
- **Result**: Verified `go test -count=1 ./...` (11/11), `python -m unittest discover -s tests -v` (61 ran: 55 ok, 6 skipped), `mdb lint`, `lint_dockerfile.py` (0 HIGH / 0 WARN), live `Dockerfile.bench` build + `tc netem` probe, and diff `< 15,000` B.

### ACT-098 -- Hotfix Release `v2.6.1`: Bucardo `sbtest4` Wait Skip & Runner `.env` Sourcing (`#394`)
- **Timestamp / Issue / Branch**: `2026-11-21T21:58Z` | Issue `#394` | `fix/issue-394-bucardo-env-v261`
- **Request**: Fix Bucardo `_sb_prepare` timeout on `bucardo_node2` `sbtest4`, align `.env` credential sourcing in `scripts/bench_pg_optimized_runner.sh`, add regression tests, update governance registers, and release `v2.6.1`.
- **Changes**: Excluded `"bucardo"` from `hs[1:]` `wcnt_opt` in `scripts/bench_pg_opt_workloads.py`; added `cd "$BENCH_ROOT"` and `.env` sourcing before `PG_PASS` in `scripts/bench_pg_optimized_runner.sh`; added unit tests in `tests/test_pg_libs.py`; bumped `VERSION`, `cmd/mdb/{main,main_test}.go`, and `Changelog` (trimmed `1.0.6`, `<= 600` lines); logged `RCA-085`.
- **Result**: Verified `go test -count=1 ./...` (11/11), `python3 -m unittest discover -s tests -v` (61 ran: 55 ok, 6 skipped), `bash -n`, `bash ./tests/test_config.sh`, `release_notes.py --tag v2.6.1 --check`, and diff `< 14,800` B.

### ACT-097 -- E2E Fixes: `mdb inject` `/var/tmp` & `haproxy_galera` `--no-deps` (`#392`)
- **Timestamp / Issue / Branch**: `2026-11-21T21:02Z` | Issue `#392` | `fix/issue-392-galera-nodeps-inject-vartmp`
- **Request**: Fix `mdb inject employees galera` under Galera's `/tmp` `tmpfs` mount and prevent `mdb up galera` from recreating `galera_01` when starting `haproxy_galera`.
- **Changes**: Updated `cmd/mdb/commands_admin.go`, `pkg/topology/{galera,topology_test}.go`, `tests/test_python_audit_fixes.py`, and `docs/RCA_REGISTER.md` (`RCA-084`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (59 ran: 53 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-096 -- Documentation Sync, `v2.6.0` Release Bump & Governance Registers (`#386`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:51Z` | Issue `#386` | `docs/issue-386-v260-docs`, `chore/issue-386-release-v260`, `docs/issue-386-governance-v260`
- **Request**: Document all durable `v2.6.0` Compose optimizations and 18-topology benchmark behavior in EN/FR guides, bump version to `2.6.0`, and synchronize governance registers.
- **Changes**: Updated `documentation/pg_multimaster{,_fr}.md` (PR `#388`), `VERSION`, `cmd/mdb/{main,main_test}.go`, `Changelog`, `ROADMAP.md` (PR `#390`), `docs/ACTION_LOGBOOK.md`, and `docs/RCA_REGISTER.md` (`RCA-083`, `IMP-016`, `APP-028`, `IDEA-014`).
- **Result**: Verified `release_notes.py --tag v2.6.0 --check`, `test_config.sh`, `unittest` (59 ran: 53 ok, 6 skipped), and `go test -count=1 ./...` (11/11).

### ACT-095 -- Unified 18-Topology Optimized Runner, Live Smoke Test & Regression Suite (`#380`, `#384`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:41Z` | Issues `#380`, `#384` | `feat/issue-380-bench-optimized-runner`, `test/issue-384-optimized-bench-tests`
- **Request**: Implement `scripts/bench_pg_optimized_runner.sh` (`--resume`, `PG_SCALE=20`, `make bench-pg-optimized`) and comprehensive unit/static tests for optimized libs and compose tunings.
- **Changes**: Added `scripts/bench_pg_optimized_runner.sh` + `Makefile` target (PR `#383`); added `TestBenchPgOptimizedLib` (`tests/test_pg_libs.py`) and `test_pg_compose_durable_tunings_and_haproxy_ram_caps` (`tests/test_repo_static.py`) (PR `#385`).
- **Result**: Verified live `pg18-standalone` smoke test (`15/15` suites, `drift=0`, `--resume` skip, `0` residual containers), `unittest` (59 ran: 53 ok, 6 skipped), and `go test -count=1 ./...` (11/11).

### ACT-094 -- Unified Optimized Benchmark Python Libraries (`#372`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:29Z` | Issue `#372` | `feat/issue-372-bench-optimized-lib`, `feat/issue-372-bench-opt-workloads`, `feat/issue-372-bench-optimized-lib-ops`
- **Request**: Build modular Python libraries supporting `fillfactor=90`, `5s` warmup, `/tmp/sb_wrap.lua` `55409`/`40001`/`40P01` retries, Citus co-location, `yb`/`crdb` chunked loading, `pgedge` `delta_apply`, `bucardo` `quick_delta_check`, and `yt-cluster` parallel configs (`CgPIAQE=`/`CgcSAhACyAEB`).
- **Changes**: Added `scripts/bench_pg_opt_common.py` (PR `#374`), `scripts/bench_pg_opt_workloads.py` (PR `#377`), and `scripts/bench_pg_optimized_lib.py` (PR `#379`), leaving legacy runners untouched.
- **Result**: Verified via `py_compile`, live CRDB `v25.4` SQL/Lua probes, `test_config.sh`, `unittest`, and `go test -count=1 ./...`.

### ACT-093 -- Multi-Master / Distributed Compose Tunings, RAM Caps & YB/CRDB HAProxy LBs (`#368`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:05Z` | Issue `#368` | `feat/issue-368-mm-dist-compose-haproxy`
- **Request**: Apply durable tuned env-var defaults and 15 GiB host `mem_limit` caps across `pgedge`, `bucardo`, `citus`, `yugabyte`, `cockroach`, and `yt-cluster`, and add HAProxy TCP load balancers for 3-node YB and CRDB.
- **Changes**: Updated 6 multi-master/distributed Compose files (`YT_MAX_PREPARED=300`, Citus `2048m`, YB/CRDB `3072m`) and created `scripts/{yugabyte,cockroach}/haproxy.cfg` (`15470`/`15480`, Docker `127.0.0.11:53` resolver) (PR `#371`).
- **Result**: Verified `haproxy -c -f` (`haproxy:lts-alpine`), `test_config.sh`, `unittest`, and `go test -count=1 ./...`.

### ACT-092 -- Durable Production-Tuned PG 17 & PG 18 Native Compose Defaults (`#361`)
- **Timestamp / Issue / Branch**: `2026-11-21T19:55Z` | Issue `#361` | `feat/issue-361-pg17-pg18-compose-tunings`, `feat/issue-361-pg18-compose-tunings`
- **Request**: Parameterize durable tuned defaults (`wal_compression=lz4`, `jit=off`, `checkpoint_completion_target=0.9`, `random_page_cost=1.1`, `logical_decoding_work_mem=256MB`, PG 18-only `io_method=worker`/`io_workers=4`) across PG 17 and PG 18 Compose stacks.
- **Changes**: Updated `docker-compose-{pg17-baseline,pg-streaming,pg-logical,pg-birep}.yml` (PR `#364`) and `docker-compose-pg18-{streaming,logical,birep}.yml` (PR `#367`), keeping `fsync=on` and `full_page_writes=on`.
- **Result**: Verified `test_config.sh`, `unittest`, and `go test -count=1 ./...` (11/11).

### ACT-091 -- E2E Fixes: Standalone PFS CLI Flags & Galera Named Volumes / `gcache.size=128M` (`#387`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:45Z` | Issue `#387` | `fix/issue-387-pfs-cli-galera-volumes`
- **Request**: Replace standalone `pfs.cnf` bind mounts with CLI flags to eliminate Windows `drvfs` `0777` ignores, and switch Galera to named Docker volumes with `gcache.size=128M`.
- **Changes**: Updated `docker-compose.yml`, `docker-compose-galera.yml`, `conf/gcustom_{1,2,3}.cnf`, `tests/test_python_audit_fixes.py`, and `docs/RCA_REGISTER.md` (`RCA-082`).
- **Result**: Verified `go test ./...` (11/11), `unittest`, `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-090 -- E2E Fixes: Windows `docker` `WSLENV` & `pgpool` Exact Resolution / Clean Replication Setup (`#381`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:38Z` | Issue `#381` | `fix/issue-381-pfs-wslenv-pgpool-galera`
- **Request**: Extend `WSLENV` forwarding to `docker` shims on Windows, prefer exact container match for `pgpool`, align `pgpool` `rootpass` default, and eliminate `pg_node2..3` `PANIC` during replication setup.
- **Changes**: Updated `pkg/docker/{client,docker_test}.go`, `cmd/mdb/{main,commands_ops,main_test}.go`, `docker-compose-pgpool.yml`, `tests/test_pgpool.sh`, `scripts/pgpool/setup_replication.sh`, and `docs/RCA_REGISTER.md` (`RCA-081`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (54 ran: 48 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-089 -- E2E Fixes: `mdb report` Catalog Resolution, `mdb bench` MySQL/PG Execution & `mdb inject` Guard (`#376`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:27Z` | Issue `#376` | `fix/issue-376-pfs-report-bench-wslenv`
- **Request**: Fix `mdb report` standalone catalog resolution, `mdb bench` standalone MySQL/MariaDB/Percona (`sysbench`) and PostgreSQL (`pgbench`) failures, and `mdb inject` MySQL warning.
- **Changes**: Updated `cmd/mdb/{commands_admin,commands_bench,commands_lint,main,main_test}.go` and `docs/RCA_REGISTER.md` (`RCA-080`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (54 ran: 48 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-088 -- E2E Fixes: InnoDB `0644` Config Copy, Idempotent Bucardo Setup, YT `t16` Retry & pgEdge Reload (`#373`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:16Z` | Issue `#373` | `fix/issue-373-innodb-bucardo-yt-pgedge`
- **Request**: Fix Windows `drvfs` `0777` `group_replication.cnf` ignore, `setup_bucardo.sh` restart race, `test_yt_cluster.sh` post-SIGKILL WAL reload race + `.env` sourcing, and `pgedge` `logging_collector` reload warning.
- **Changes**: Updated `docker-compose-innodb-cluster.yml`, `conf/innodb-cluster/setup_cluster.sh`, `scripts/bucardo/setup_bucardo.sh`, `scripts/yt_cluster/setup_yt_cluster.sh`, `tests/test_yt_cluster.sh`, `scripts/pgedge/setup_pgedge.sh`, `tests/test_python_audit_fixes.py`, and `docs/RCA_REGISTER.md` (`RCA-079`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (54 ran: 48 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-087 -- E2E Fixes: `pgpool:4.4.3` + `0600` SSL Copy, `pgpool`/`cockroach`/`yugabyte` Verifiers & `yb_node3` Join Serialization (`#369`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:09Z` | Issue `#369` | `fix/issue-369-pgpool-crdb-yb`
- **Request**: Fix `pgpool` broken tag & Windows `0777` SSL keys, `pgpool`/`cockroach`/`yugabyte` Go verifiers, and `yb_node3` join race crash.
- **Changes**: Updated `docker-compose-pgpool.yml`, `documentation/pgpool_cluster.md`, `docker-compose-yugabyte.yml`, `pkg/dbclient/{postgres,postgres_mongo_test}.go`, and `docs/RCA_REGISTER.md` (`RCA-078`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (53 ran: 47 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-086 -- E2E Fixes: `repli`/`galera` Container Resolution, Vertical `\G` Queries & Windows `mdb clean` Mount (`#365`)
- **Timestamp / Issue / Branch**: `2026-11-21T20:02Z` | Issue `#365` | `fix/issue-365-repli-galera-clean`
- **Request**: Resolve Compose container names for `repli`/`galera`, remove `-sN` on `\G` replication queries, and fix Windows `mdb clean` alpine bind-mount path handling.
- **Changes**: Updated `pkg/topology/{topology,galera,topology_test}.go`, `pkg/dbclient/{mysql,dbclient_test}.go`, `tests/test_repli.sh`, `cmd/mdb/{commands_admin,main_test}.go`, and `docs/RCA_REGISTER.md` (`RCA-077`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (53 ran: 47 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-085 -- Parameterizable Traefik & Galera Host Ports + `mycnf`/`doctor` Port Hints (`#362`)
- **Timestamp / Issue / Branch**: `2026-11-21T19:55Z` | Issue `#362` | `feat/issue-362-configurable-host-ports`
- **Request**: Parameterize Traefik (`3306`/`5432`) and Galera (`3306`) host ports with defaults preserved, wire `TRAEFIK_MYSQL_PORT` into `mdb mycnf`, and add localhost port-in-use warnings to `mdb doctor`.
- **Changes**: Updated `docker-compose.yml`, `docker-compose-galera.yml`, `tests/{test_galera,test_haproxy_galera,test_lb_galera}.sh`, `tests/{test_lab,test_python_audit_fixes}.py`, `cmd/mdb/{commands_ops,main_test}.go`, and `docs/RCA_REGISTER.md` (`RCA-076`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (53 ran: 47 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-084 -- E2E Fixes: Setup/Suite `DB_ROOT_PASSWORD`, `test_mongo_rs.sh` Args, `test_lab.py` Timeouts & `DefaultService` (`#359`)
- **Timestamp / Issue / Branch**: `2026-11-21T19:47Z` | Issue `#359` | `fix/issue-359-env-timeouts-defaults`
- **Request**: Propagate `DB_ROOT_PASSWORD` to setup/`--suite` scripts when unset, accept positional node args in `tests/test_mongo_rs.sh`, bound `tests/test_lab.py` query timeouts, and align `DefaultService` to `mariadb114`.
- **Changes**: Updated `pkg/topology/{topology,topology_test}.go`, `cmd/mdb/{commands_lint,main_test}.go`, `pkg/config/{config,config_test}.go`, `tests/{test_mongo_rs.sh,test_lab.py,test_python_audit_fixes.py}`, and `docs/RCA_REGISTER.md` (`RCA-075`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (53 ran: 47 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-083 -- E2E Fixes: Compose Orphan Isolation & Windows `WSLENV` Forwarding (`#357`)
- **Timestamp / Issue / Branch**: `2026-11-21T19:35Z` | Issue `#357` | `fix/issue-357-e2e-compose-env-timeouts`
- **Request**: Fix cross-topology `ComposePS` orphan leakage and Windows->WSL `bash.exe` `extraEnv` stripping.
- **Changes**: Updated `pkg/docker/{client,compose,docker_test}.go`, `cmd/mdb/{commands_inspect,main_test}.go`, and `docs/RCA_REGISTER.md` (`RCA-074`).
- **Result**: Verified `go test ./...` (11/11), `unittest` (52 ran: 46 ok, 6 skipped), `mdb lint`, diff `< 15,000` B, and CI `test-and-validate` green.

### ACT-082 -- Governance & Roadmap Sync for `v2.5.0` (`#355`)
- **Timestamp / Issue / Branch**: `2026-11-21T01:03Z` | Issue `#355` | `docs/issue-355-governance-v250`
- **Request**: Record the 12 Usability Audit RCAs, `./mdb` architecture decision, YT Cluster caveats, Phase 14, and PR metrics across governance files.
- **Changes**: Updated [`ROADMAP.md`](../ROADMAP.md) (Phases 1–14, `IDEA-001`–`IDEA-013`, `APP-001`–`APP-027`), [`docs/RCA_REGISTER.md`](RCA_REGISTER.md) (`RCA-072`–`073`, `IMP-015`, `APP-025`–`027`, `IDEA-012`–`013`), and [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md) (Phase 14 + `ACT-080`–`082`).
- **Result**: Verified `test_project_governance_rules.py`, `unittest` (52 ran: 46 ok, 6 skipped), `go test ./...` (11/11), `release_notes.py`, and `< 15K` B diff.

### ACT-081 -- EN/FR Docs Sync, Rules, PG Stacks & `v2.5.0` Release (`#339`, `#348`, `#351`, `#353`)
- **Timestamp / Issue / Branch**: `2026-11-21T00:58Z` | Issues `#339`, `#348`, `#351`, `#353` | PRs `#340`, `#341`, `#346`, `#349`, `#350`, `#352`, `#354`
- **Request**: Establish `./mdb` (`mdb.cmd`) as unified entry point in EN/FR docs & rules, sync 13 PG stacks/YT Cluster 1.21.3/license/Jepsen notes, and release `v2.5.0`.
- **Changes**:
  - PR `#340` (`03eca84`, `13,974` B, CI `2m55s`): `README.md` (`./mdb`, Win/macOS, `pg17-baseline`, `yt-cluster`).
  - PR `#341` (`53012c2`, `9,591` B, CI `3m19s`): `AGENTS.md`, `00_constitution.md`, `PREREQUISITES.txt`, `INDEX.md`, `architecture.md`.
  - PR `#346` (`df06f6b`, `13,270` B, CI `2m47s`, Closes `#339`): `makefile.md`, `scripts.md`.
  - PR `#349` (`b693234`, `13,565` B, CI `2m19s`) & `#350` (`1121270`, `13,799` B, CI `2m49s`, Closes `#348`): EN/FR `pg_multimaster` & `supported_products` (`haproxy:lts-alpine`, `cockroachdb:latest-v25.4`, 13 PG stacks, MIT vs PolyForm, Jepsen 49/49).
  - PR `#352` (`663307d`, `13,034` B, CI `1m58s`) & `#354` (`449b6a8`, `12,685` B, CI `2m35s`, Closes `#351`, `#353`): `README_fr.md`, `INDEX_fr.md`, `makefile_fr.md`, `VERSION`/`main.go`/`main_test.go`/`Changelog` -> `2.5.0` (592 lines).
- **Result**: All 7 PRs `< 15K` B passed CI `test-and-validate`, `@verifier-3` (WSL `go test -race -count=1 ./...` 11/11, `unittest`, `make lint`), and `release_notes.py --tag v2.5.0 --check`.

### ACT-080 -- Environment Catalog, Unified `./mdb` CLI & 12 Usability Fixes (`#302`–`#337`)
- **Timestamp / Issue / Branch**: `2026-11-20T22:05Z`–`2026-11-21T00:16Z` | 18 Issues (`#302`–`#337`) | 18 PRs
- **Request**: Build queryable catalog, unify `./mdb`/`mdb.cmd` across engines + bilingual wizard, and resolve Usability Audit `#1`–`#12`.
- **Changes**:
  - **Catalog & Docker** (`#303` `dd1e30e`, `#305` `9487ebd`, `#307` `0116e61`, `#309` `e66e018`): `pkg/catalog`, `pkg/docker` profile/multi-compose/image helpers, auto-PKI, readiness polling, `MONGO_NODES` in `setup_rs.sh`, standalone/galera/repli hardening.
  - **Unified `./mdb` & Wizard** (`#311` `6c31520`, `#313` `3dbc7c1`, `#315` `0816553`, `#317` `93df3d3`, `#320` `3461dd8`, `#324` `5392365`, `#329` `36b02ac`, `#333` `65325bb`, `#335` `19352ad`): unified `./mdb`/`mdb.cmd`, multi-engine `client`/`bench`, `status`/`info`/`logs`, `0600` `mycnf`, `doctor`, bilingual Go wizard (`html.EscapeString`), unconditional `yt-cluster`, `pg17-baseline`, `setup`/`lint`/`test --suite`.
  - **Makefile & Python UX** (`#322` `3075581`, `#325` `9b3013e`, `#330` `80c23b2`, `#332` `6c41ee5`, `#338` `3d0d05d`): `./mdb` wrappers, `galera-*/repli-*` & 13 PG stack targets, `seq 1 60`, `docker exec` `pgpool-status`, `rootpass` fallback, Python UX fixes & deprecation warnings.
- **Result**: All 18 PRs `< 15K` B merged (`dd1e30e`..`3d0d05d`) with CI `test-and-validate` green and verified on `origin/main` via `unittest` and `go test`.

### ACT-079 -- EN/FR Multi-Master Guide Sync for Full YT Async Matrix (`#345`)
- **Date**: `2026-11-21T00:34+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#345`
- **Request**: Update `documentation/pg_multimaster{,_fr}.md` with `v2.4.1`, 18-suite `yt-cluster-async` benchmarks, non-Leader WAN methodology, and `SQLSTATE 55000` `recon` quarantine notes.
- **Changes**: Updated `documentation/pg_multimaster.md`, `documentation/pg_multimaster_fr.md`, and `RCA-071` reference.
- **Result**: Diff `< 14,500` B; `test_config.sh`, `unittest`, and `go test` pass cleanly prior to tagging `v2.4.1`.

### ACT-078 -- Release `v2.4.1` Version Bump & EN/FR YT Async Matrix Docs (Issue `#343`)
- **Date**: `2026-11-21T00:32+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#343`
- **Request**: Bump `multi-db-docker-env` to `v2.4.1` and document the complete 18-suite `yt-cluster-async` benchmarks and `SQLSTATE 55000` `recon` quarantine finding.
- **Changes**: Bumped `VERSION`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, `Makefile` to `2.4.1`; prepended `2.4.1` to `Changelog` (trimmed <= 600 lines); updated `documentation/pg_multimaster{,_fr}.md`, `Phase 13`, and `RCA-071`.
- **Result**: Diff `< 14,500` B; `release_notes.py --tag v2.4.1 --check`, `test_config.sh`, `unittest`, and `go test` pass.

### ACT-077 -- 18-Suite `yt-cluster-async` Runner (`#336`)
- **Date**: `2026-11-21T00:25+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#336`
- **Request**: Complete 18-suite `yt-cluster-async` runner and fix WAN/E3 issues.
- **Changes**: `scripts/bench_yt_runner.sh` (`set_async()`, `YT_ASYNC_MISSING_ONLY=1`, non-Leader WAN, `prep_sb()` before `E3`), `RCA-071`.
- **Result**: Diff `< 14,500` B; `test_config.sh`, `unittest`, `go test` pass; 36/36 rows (`E3=133.55`, `WAN 8.47->2.90`).

---

### ACT-076 -- YT Cluster 1.21.3 (PG 18.7) Active-Active Topology, Benchmark Suite & `v2.4.0` Release (Issues `#288`, `#290`, `#292`, `#294`, `#296`, `#298`, `#300`)
- **Date**: `2026-11-20T20:05+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#288`/`#289`, `#290`/`#291`, `#292`/`#293`, `#294`/`#295`, `#296`/`#297`, `#298`/`#299`, `#300`
- **Request**: Land the live-verified 3-node YT Cluster 1.21.3 (`dbinvent/yt:1.21.3`, PG 18.7 + `yt_cluster 1.21` / `ytserv`) active-active Docker Compose stack, setup script, functional/limits/reversibility test suite, sequential benchmark runner, Makefile & Go `mdb` CLI integration (20 topologies), EN/FR documentation, governance registers, and annotated release tag `v2.4.0` via atomic `< 15K` PRs.
- **Changes**: Added `docker-compose-yt-cluster.yml`, `scripts/yt_cluster/setup_yt_cluster.sh`, `tests/test_yt_cluster.sh`, and `scripts/bench_yt_runner.sh`; wired `Makefile` (`yt-cluster-*`, `bench-yt-cluster`, `clean-pg18`), `pkg/topology/` (20 topologies), `pkg/dbclient/`, and `cmd/mdb/`; bumped `VERSION` to `2.4.0` and prepended `2.4.0` to `Changelog` (597 lines <= 600); synchronized `documentation/pg_multimaster{,_fr}.md`, `README{,_fr}.md`, `docs/ACTION_LOGBOOK.md` (`Phase 13`, `ACT-076`), and `docs/RCA_REGISTER.md` (`RCA-068`–`RCA-070`, `IMP-014`, `APP-024`, `IDEA-011`).
- **Result**: All 7 atomic PRs strictly `< 14,800` B; `docker compose -f docker-compose-yt-cluster.yml config -q`, `bash ./tests/test_config.sh`, `PGCONNECT_TIMEOUT=2 python3 -m unittest discover -s tests -v` (48 tests, 0 failures), `go test -count=1 ./...` (9/9), and `python3 scripts/release_notes.py --tag v2.4.0 --check` pass; `./bin/mdb version` prints `mdb version 2.4.0` and `./bin/mdb topologies` lists all 20 topologies; annotated tag `v2.4.0` pushed to `origin`.

---

### ACT-075 -- Database & Proxy Version Upgrades and Official EOL Decommissioning (Issues `#274`, `#275`, `#276`, `#279`, `#280`, `#284`, `#286`)
- **Date**: `2026-11-20T18:45+01:00`
- **Status**: `COMPLETED`
- **Issues / PRs**: `#275`/PR `#277` (Compose & Cluster Configs, 10,438 chars), `#280`/PR `#282` (`Makefile` upgrades & EOL notices, 13,070 chars), `#276`/PR `#283` (Python runner & static EOL tests, 8,709 chars), `#274`/PR `#278` (EN supported products & EOL matrix, 12,198 bytes), `#279`/PR `#281` (FR supported products & EOL matrix, 12,535 bytes), `#284`/PR `#285` (EN/FR Makefile, PG, Architecture guides, 13,082 bytes), `#286` (Governance registers & `Changelog`).
- **Request**: Audit all database and proxy versions against official community EOL dates (as of `2026-11-20`), upgrade to active LTS/current releases, and cleanly decommission all End-of-Life versions across Compose stacks, `Makefile`, Python runner, tests, EN/FR documentation, and governance registers.
- **Changes**:
  - Upgraded `docker-compose.yml` (`traefik:v3`, added `mysql97`, `mariadb123`, `percona84`, `postgres18` mounting `/var/lib/postgresql`, removed EOL `mysql57`/`mysql80`/`mysql96`/`mariadb106`/`percona80`), InnoDB Cluster (`mysql:8.4` + removed `transaction-write-set-extraction=XXHASH64` + `RESET BINARY LOGS AND GTIDS;`), CockroachDB (`latest-v25.4`), and HAProxy (`haproxy:lts-alpine` in PG clusters).
  - Updated `Makefile` with active targets and explicit EOL decommissioning notices (`exit 1` with official EOL date + replacement), updated `interactive_runner.py` and `tests/test_lab.py` (`is_mysql97`), and added static regression test `test_no_eol_images_and_pg18_volume_mount` in `tests/test_repo_static.py`.
  - Updated EN/FR supported products matrices (`documentation/supported_products{,_fr}.md`), `README{,_fr}.md`, technical guides (`makefile{,_fr}.md`, `postgresql_support{,_fr}.md`, `architecture.md`), `Changelog`, `ROADMAP.md`, `docs/RCA_REGISTER.md` (`RCA-067`, `IMP-013`, `APP-023`), and `docs/ACTION_LOGBOOK.md` (`Phase 12`, `ACT-075`).
- **Result**: `python -m unittest discover -s tests -v` (`48` ran, `42` ok, `6` live-DB skipped), `go test ./...` (`9/9` packages ok), `bash tests/test_config.sh` (ok), CI `test-and-validate` green on every PR; all PR diffs strictly `< 15,000` characters.

---

### ACT-074 -- PostgreSQL 18.6 Native Clustering Topologies, Benchmark Suite & `v2.3.0` Release (Issues `#252`, `#254`, `#256`, `#258`, `#260`, `#262`, `#264`, `#266`, `#268`, `#270`, `#272`)
- **Date**: `2026-11-20T15:55+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#252`/`#253`, `#254`/`#255`, `#256`/`#257`, `#258`/`#259`, `#260`/`#261`, `#262`/`#263`, `#264`/`#265`, `#266`/`#267`, `#268`/`#269`, `#270`/`#271`, `#272`
- **Request**: Land all live-verified PostgreSQL 18.6 native clustering stacks (`pg18-streaming`, `pg18-logical`, `pg18-birep`), functional/limits test suites, sequential benchmark suite (`bench-pg18`), Makefile & Go `mdb` CLI wiring (19 topologies), bilingual documentation, governance updates, and release tag `v2.3.0` via atomic `< 15K` PRs.
- **Changes**: Added `docker-compose-pg18-{streaming,logical,birep}.yml`, `scripts/pg18_*/`, `tests/test_pg18_*.sh`, `scripts/bench_pg18_{runner.sh,lib.py}`; wired `Makefile` (`pg18-*`, `bench-pg18`, `clean-pg18`), `pkg/topology/` (19 topologies), `pkg/dbclient/`, `cmd/mdb/`; bumped `VERSION` to `2.3.0` with FIFO-rotated `Changelog`; documented PG 18.6 stacks and findings in `documentation/pg_multimaster{,_fr}.md`, `README{,_fr}.md`, `docs/ACTION_LOGBOOK.md`, and `docs/RCA_REGISTER.md` (`RCA-064`–`RCA-066`, `IMP-012`, `APP-022`, `IDEA-010`).
- **Result**: All 11 atomic PRs strictly `< 14,800` B; `docker compose config --quiet` passes on all 3 PG 18 stacks; `python3 -m unittest discover -s tests -v` (46 ran, 40 passed, 6 live-DB skipped, 0 failed) and `go test -count=1 ./...` (9/9) pass; `./bin/mdb version` prints `mdb version 2.3.0` and `./bin/mdb topologies` lists all 19 topologies; annotated tag `v2.3.0` pushed to `origin`.

---

### ACT-073 -- Pin MySQLTuner `v2.9.4` in CI & Print Failure Tail in `run_mysqltuner.sh` (Issue `#250`)
- **Date**: `2026-11-20T15:18+01:00` | **Status**: `COMPLETED` | **Issue / Branch**: `#250` (`fix/issue-250-ci-mysqltuner`)
- **Request**: Diagnose and fix `test-and-validate` CI failure in `Run MySQLTuner E2E Integration Audit` (`make mysqltuner-galera`, exit 255 on all 3 Galera nodes) exposed after PR `#240`, and surface `$OUTPUT_FILE` failure diagnostics to stderr.
- **Changes**: Upgraded pinned MySQLTuner download in `.github/workflows/ci.yml` from `v2.6.0` to `v2.9.4` (fixes division by zero on MariaDB 11.8 `innodb_buffer_pool_chunk_size=0`); updated `scripts/run_mysqltuner.sh` to print the last 30 lines of `$OUTPUT_FILE` to stderr on node failure; logged `RCA-063`.
- **Result**: Local `bash -n scripts/run_mysqltuner.sh` and `python -m unittest discover -s tests -v` pass; GitHub Actions `test-and-validate` verified green on PR.

---

### ACT-072 -- Release Pipeline Docs, `Changelog` & Governance Register Consolidation (Issues `#244`, `#245`)
- **Date**: `2026-11-20T15:10+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#244`/`#246`, `#245` (`docs/issue-245-governance-consolidation`)
- **Request**: Document `.github/workflows/release.yml`, `scripts/release_notes.py`, and `PREREQUISITES.txt`; update `Changelog`; consolidate `docs/ACTION_LOGBOOK.md`, `docs/RCA_REGISTER.md`, `ROADMAP.md`, and `POTENTIAL_ISSUES.md` with zero drifting tracking lists.
- **Changes**: Updated `README.md`, `README_fr.md`, `documentation/scripts.md`, `Changelog`, `docs/ACTION_LOGBOOK.md`, `docs/RCA_REGISTER.md`, `ROADMAP.md`, and `POTENTIAL_ISSUES.md` across two atomic `< 15K` PRs.
- **Result**: `python -m unittest discover -s tests -v` (46 ran, 40 passed, 6 live-DB skipped, 0 failed) and `go test ./...` (9/9) pass; zero broken links or duplicate trackers.

---

### ACT-071 -- Ponytail Audit Remediation: Go, Python, Makefile, Shell & Docker Hardening (Issues `#225`, `#227`, `#237`, `#242`)
- **Date**: `2026-11-20T15:08+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#225`/`#234` (`c519722`), `#227`/`#240` (`4813548`), `#237`/`#241` (`539fe42`), `#242`/`#243` (`52f56cb`)
- **Request**: Remediate all 18 ranked findings + 6 smaller items from the repository-wide Ponytail quality and security audit.
- **Changes**: Fixed expired cert verification (`pkg/pki/cert.go`), 9 missing `NewVerifier` topologies (`pkg/dbclient`), `Seconds_Behind_Source` fallback, sysbench password/error handling (`pkg/bench`), `bench_pg_lib.py` `chk=False` args, `interactive_runner.py` PG target & `html.escape`, `mysql_docker.py` `chmod 600`/CLI/rm fixes, logical backup/restore `pipefail` + positional args, `Makefile` syntax/TLS/exit-code/logs fixes, runtime `ssh-keygen`, removal of `privileged: true` & dead/duplicate files (`setup_rs_mongo8.sh`, `conf/mongo-rs/keyfile`, `.code-workspace.bak`), `requirements.txt` -> `PREREQUISITES.txt`, and `mysql57` Traefik profile.
- **Result**: All 4 atomic PRs (`< 15K` each, `-107` net lines on PR `#243`) verified by `@verifier` and merged onto `main`; `go test ./...` (9/9) and 46 Python tests pass.

---

### ACT-070 -- Expanded Deterministic Test Coverage & Test-Directory Audit Fixes (Issues `#223`, `#228`, `#229`)
- **Date**: `2026-11-20T15:03+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#223`/`#226` (`b76748a`), `#228`/`#233` (`cd4dfba`), `#229`/`#238` (`3516eed`)
- **Request**: Validate local tests and broaden deterministic Python, Go, and static repository test coverage plus audit fixes in `tests/`.
- **Changes**: Expanded `tests/test_python_runners.py`, added `tests/test_pg_libs.py` and `tests/test_repo_static.py` (with stdlib fallback when PyYAML is absent), expanded `cmd/mdb/main_test.go` (`cmd/mdb` coverage `13.8%` -> `44.2%`), and fixed `tests/test_failover.sh`, `tests/test_lab.py`, and `tests/test_config.sh`.
- **Result**: Python unit tests doubled from 21 (15 ok) to 46 (40 ok, 6 live-DB skipped, 0 failed); `go test -cover ./...` 9/9 pass; `bash -n` 60/60 pass.

---

### ACT-069 -- Documentation Stack Audit & Bilingual `v2.2.0` Synchronization (Issues `#224`, `#231`, `#232`)
- **Date**: `2026-11-20T15:02+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#224`/`#230` (`fb688f3`), `#231`/`#235` (`b445a42`), `#232`/`#236` (`469fd24`)
- **Request**: Audit and synchronize `README.md`, `README_fr.md`, `documentation/INDEX{,_fr}.md`, and technical guides with the `v2.2.0` codebase.
- **Changes**: Fixed stale CLI versions (`2.0.25`/`2.0.2` -> `2.2.0`), topology count (`8` -> `16`), removed phantom targets (`percona84`, `pgpass`, `pgclient`, Percona 8.4), fixed MongoDB TLS flags and `make start` default (`mariadb114`), updated legacy index titles, and added v2.1–v2.2 PostgreSQL & MongoDB 8 docs.
- **Result**: All 3 atomic PRs (`13,332 B`, `11,296 B`, `4,776 B`) passed CI `test-and-validate`, `@verifier` review, and link audit (0 broken links).

---

### ACT-068 -- Automated GitHub Actions Release Pipeline (Issue `#222`)
- **Date**: `2026-11-20T14:59+01:00` | **Status**: `COMPLETED` | **Issue / PR**: `#222` / `#239` (`48e41a4`)
- **Request**: Implement an automated tag-triggered and `workflow_dispatch` GitHub Actions release workflow with version validation, test gate, 6-target `mdb` cross-compilation, checksums, and Changelog extraction.
- **Changes**: Updated `.github/workflows/release.yml`, added stdlib-only `scripts/release_notes.py` and `tests/test_release_workflow.py` (diff `14,960 B` < `15,000`).
- **Result**: Verified by `@verifier`, CI `test-and-validate` green, merged onto `main`.

---

### ACT-067 -- Governance Registers & V2 Empirical RCA Consolidation (Issue `#220`)
- **Date**: `2026-11-19T16:58+01:00` | **Status**: `COMPLETED` | **Issue / Branch**: `#220` (`docs/issue-220-registers-v220`)
- **Request**: Record all `v2.2.0` PostgreSQL streaming, logical, extended matrix, and V2 benchmark actions (`ACT-063`-`ACT-067`), Phase 9 milestone, and verified V2 RCAs (`RCA-054`-`RCA-057`), dead-end (`IMP-010`), approximation (`APP-020`), and idea (`IDEA-008`).
- **Changes**: Updated `docs/ACTION_LOGBOOK.md` and `docs/RCA_REGISTER.md` in pure ASCII English.
- **Result**: `unittest` (21 tests), `go test -count=1 ./...`, and `make build-go` pass.

---

### ACT-066 -- Bilingual V2 Documentation Sync (Issues `#216`, `#218`)
- **Date**: `2026-11-19T16:57+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#216`/`#217` (`da8307a`), `#218`/`#219` (`af37c27`)
- **Request**: Document `pg-streaming`, `pg-logical`, `make test-pg-extended` (`T11`-`T18`), `make bench-pg-v2`, and the companion `ClusterPostgreSQL-Series` study in English and French guides.
- **Changes**: Updated `documentation/pg_multimaster.md` (PR `#217`, 8,893 B) and `documentation/pg_multimaster_fr.md` (PR `#219`, 9,248 B).
- **Result**: Both PRs merged onto `main`; all tests pass.

---

### ACT-065 -- Makefile Targets, Go CLI 16-Topology Registry & `v2.2.0` Release (Issue `#214`)
- **Date**: `2026-11-19T16:52+01:00` | **Status**: `COMPLETED` | **Issue / PR**: `#214` / `#215` (`5e2de6c`)
- **Request**: Wire `pg-streaming-{up,down,status,logs,ps,test}`, `pg-logical-{up,down,status,logs,ps,test}`, `test-pg-extended`, and `bench-pg-v2` in `Makefile`, register `pg-streaming` and `pg-logical` in `pkg/topology` and `cmd/mdb`, and release `v2.2.0`.
- **Changes**: Updated `Makefile`, `pkg/topology/pg_multimaster.go`, `pkg/topology/topology.go`, `pkg/topology/topology_test.go`, `cmd/mdb/main.go`, `cmd/mdb/main_test.go`, `VERSION` (`2.2.0`), and `Changelog` (PR `#215`, 14,037 B).
- **Result**: `./bin/mdb version` -> `mdb version 2.2.0`; `./bin/mdb topologies` -> 16 alphabetical topologies; `unittest`, `test_config.sh`, `go test`, and `make build-go` pass.

---

### ACT-064 -- Extended `T11`-`T18` Empirical Matrix & V2 Sequential Benchmark Harness (Issues `#206`, `#208`, `#210`, `#212`)
- **Date**: `2026-11-19T16:48+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#206`/`#207` (`ec88a73`), `#208`/`#209` (`ef47255`), `#210`/`#211` (`8113975`), `#212`/`#213` (`1756412`)
- **Request**: Land the sequential `T11`-`T18` extended test matrix and V2 benchmark harness (`E2`-`E4`, `H_append_only_insert`, `G_conc_c1..c32`, WAN `10/25/50ms`) across all 10 PostgreSQL topologies via atomic `< 15K` PRs.
- **Changes**: Added `scripts/test_pg_extended_matrix.sh` (13,161 B), `scripts/test_pg_extended_lib.py` (13,409 B), `scripts/bench_pg_v2_runner.sh` (11,080 B), and `scripts/bench_pg_v2_lib.py` (12,889 B).
- **Result**: All 4 PRs merged onto `main`; all shell scripts declare `set -euo pipefail` (mode `100755`); `unittest`, `go test`, and `make build-go` pass.

---

### ACT-063 -- PostgreSQL 17 Physical Streaming & Native Logical Topologies + Test Suites (Issues `#198`, `#200`, `#202`, `#204`)
- **Date**: `2026-11-19T16:43+01:00` | **Status**: `COMPLETED` | **Issues / PRs**: `#198`/`#199` (`4226130`), `#200`/`#201` (`d93ba3d`), `#202`/`#203` (`d430ee6`), `#204`/`#205` (`31e9f51`)
- **Request**: Land `pg-streaming` (async/sync physical WAL + `pg_promote()`) and `pg-logical` (uni-directional `pub_logical` -> `sub_logical`) compose stacks, setup scripts, and live-verified test suites.
- **Changes**: Added `docker-compose-pg-streaming.yml`, `scripts/pg_streaming/setup_pg_streaming.sh`, `tests/test_pg_streaming.sh`, `docker-compose-pg-logical.yml`, `scripts/pg_logical/setup_pg_logical.sh`, and `tests/test_pg_logical.sh`; purged scratch `reports/test_*_20261119_*` dumps.
- **Result**: All 4 PRs merged cleanly (`< 10 KB` each); `unittest`, `go test`, and `make build-go` pass.

---

### ACT-062 — Governance Registers & Empirical RCA Consolidation (Issue `#196`)
- **Date**: `2026-11-19T13:21+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#196` (`docs/issue-196-registers-v210`)
- **Request**: Record all v2.1.0 PostgreSQL multi-master actions (`ACT-054`–`ACT-062`), Phase 8 milestone, and all empirically verified RCAs (`RCA-049`–`RCA-053`), dead-ends (`IMP-009`), approximations (`APP-019`), and ideas (`IDEA-007`).
- **Changes**: Updated `docs/ACTION_LOGBOOK.md` and `docs/RCA_REGISTER.md`.
- **Result**: `unittest` (21 tests), `test_config.sh`, `go test ./...`, and `make build-go` pass.

---

### ACT-061 — Bilingual Multi-Master Documentation (`documentation/pg_multimaster{,_fr}.md`) (Issues `#192`, `#194`)
- **Date**: `2026-11-19T13:20+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#192`, `#194` (PRs `#193`, `#195`)
- **Request**: Document all 6 multi-master/distributed PostgreSQL topologies, `pg17-baseline`, empirical benchmark tables (`PG_SCALE=2`, Suites A–F), and observed SQLSTATE failure modes in English and French.
- **Changes**: Added `documentation/pg_multimaster.md`, `documentation/pg_multimaster_fr.md`, and links in `documentation/INDEX.md` and `documentation/INDEX_fr.md`.
- **Result**: Merged PRs `#193` (`1c68591`) and `#195` (`a2216e8`). All tests pass.

---

### ACT-060 — Makefile Targets, Go Topology Registry & `v2.1.0` Bump (Issues `#188`, `#190`)
- **Date**: `2026-11-19T13:18+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#188`, `#190` (PRs `#189`, `#191`)
- **Request**: Wire `<topo>-{up,down,status,logs,ps}`, `test-<topo>`, and `bench-pg-multimaster` in `Makefile`, register the 6 new topologies in `pkg/topology`, sync `cmd/mdb`, and release `2.1.0`.
- **Changes**: Updated `Makefile` (PR `#189`, `de204ec`); added `pkg/topology/pg_multimaster.go`, updated `topology.go`, `topology_test.go` (14 topologies), `VERSION` (`2.1.0`), `cmd/mdb/main.go`, `main_test.go`, and `Changelog` (PR `#191`, `3dc1419`).
- **Result**: `mdb version 2.1.0`, 14 topologies listed, `unittest`, `test_config.sh`, `go test`, and `make build-go` pass.

---

### ACT-059 — PG17 Baseline & Sequential Benchmark Harness (`PG_SCALE=2`) (Issues `#184`, `#186`)
- **Date**: `2026-11-19T13:13+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#184`, `#186` (PRs `#185`, `#187`)
- **Request**: Land `scripts/bench_pg_lib.py`, `scripts/bench_pg_multimaster.sh`, and `docker-compose-pg17-baseline.yml` executing Suites A–F (`pgbench`, `sysbench`, `tc netem 25ms`) sequentially across 8 topologies.
- **Changes**: Added `scripts/bench_pg_lib.py` (PR `#185`, `a44f96f`), `docker-compose-pg17-baseline.yml` and `scripts/bench_pg_multimaster.sh` (PR `#187`, `f1f254b`).
- **Result**: 56 empirical benchmark rows validated (`spock.delta_apply` 1,837.64 TPS / 0 drift; `tc netem 25ms` WAN collapse verified).

---

### ACT-054..058 — Six PostgreSQL Multi-Master & Distributed SQL PoCs + Limit Test Suites (Issues `#160`–`#182`)
- **Date**: `2026-11-19T13:11+01:00` · **Status**: `COMPLETED` · **Issues / PRs**: `#160`/`#161`, `#162`/`#163`, `#164`/`#165`, `#166`/`#167`, `#168`/`#169`, `#170`/`#171`, `#172`/`#173`, `#174`/`#175`, `#176`/`#177`, `#178`/`#179`, `#180`/`#181`, `#182`/`#183`
- **Request**: Land compose stacks, setup scripts, and live-verified functional + empirical limit test suites for `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, and `yugabyte` via atomic `<15K` PRs.
- **Changes**: Added `docker-compose-{pg-birep,pgedge,bucardo,citus,cockroach,yugabyte}.yml`, `scripts/{pg_birep,pgedge,bucardo,citus,cockroach,yugabyte}/*`, and `tests/test_{pg_birep,pgedge,bucardo,citus,cockroach,yugabyte}.sh`.
- **Result**: All 12 PRs merged onto `main` (`0c56c65`), live limit tests captured exact SQLSTATEs (`23505`, `55000`, `0A000`, `40001`, `XCEXF`, `42601`, `57014`, `42501`), and zero orphan containers/scratch dumps left.

---

### ACT-053 — Security Leaks Remediation & Automated Release Distribution (Issue `#156`)
- **Date**: `2026-11-10T00:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#156` (`fix/issue-156-security-remediation-and-release-automation`)
- **Request**: Remediate leaked PAT in documentation/sourcery_ai_audit.md, remove hardcoded root password and SSH private key copying in Dockerfile and Makefile, untrack .env and supply .env.example, add .dockerignore, and deploy GitHub Actions release workflow with multi-arch Docker Hub publishing and package archives.
- **Changes**: Redacted 4 occurrences of leaked PAT in `documentation/sourcery_ai_audit.md`; removed `root:rootpass` and `COPY id_rsa*` from `Dockerfile`; removed `id_rsa` key generation in `Makefile`; untracked `.env` via `git rm --cached` and created `.env.example`; created `.dockerignore`; created `.github/workflows/release.yml`; added release & Docker Hub badges in `README.md` and `README_fr.md`.
- **Result**: `test_project_governance_rules.py` (5/5), `unittest` (21/21), `go test` (67/67), and `test_env.sh` passed cleanly. Zero plaintext tokens or hardcoded private keys remaining.

---

### ACT-052 — Enforce Systematic 9-Step GitHub Workflow and English-Only Policy (Issue `#154`)
- **Date**: `2026-11-02T10:10+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#154` (`docs/issue-154-enforce-9step-workflow-english-policy`)
- **Request**: Enforce systematic 9-step GitHub workflow (Steps 0-8) with literal `git add` and `git commit`, plus Section 5 English-only policy in AGENTS.md and .agents/AGENTS.md to satisfy project governance and adversarial tests.
- **Changes**: Updated `AGENTS.md` and `.agents/AGENTS.md` with explicit 9 steps (0 to 8) and strict English-only policy; updated registers.
- **Result**: `unittest` (21/21) and governance rules pass. PR diff strictly < 15,000 characters.

---

### ACT-051 — Patroni & PostgreSQL Docs Sync with CLI and Tests (Issue `#152`)
- **Date**: `2026-11-02T09:15+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#152` (`docs/issue-152-patroni-docs-sync`)
- **Request**: Sync Patroni & PG docs with ports (5000/5001/6432/7000/8008/2379), PGPASSWORD examples, mdb CLI commands, and 8 test groups; bump to 2.0.25.
- **Changes**: Updated `patroni_cluster.md`, `postgresql_support.md`, `README.md`, `Makefile`, `VERSION`, `cmd/mdb`; updated `Changelog` and registers.
- **Result**: `unittest` (21/21), `go test` (67/67), `test_config.sh` pass. Diff < 15k.

---

### ACT-050 — Mongo 8 TLS Parity & Script Resilience (Issue `#150`)
- **Date**: `2026-11-02T08:30+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#150` (`feat/issue-150-mongo8-tls-parity`)
- **Request**: Add Mongo 8 TLS mounts/flags, 3-tier run_mongosh, Makefile prereqs, RequiredCerts, tests.
- **Changes**: Added 3-tier run_mongosh in setup; mounted certs with requireTLS in compose; updated Makefile/Go topology; added tests; bumped to 2.0.24.
- **Result**: `unittest` (21/21), `go test` (67/67), `test_config.sh` pass. Diff < 15k.

---

### ACT-049 — Makefile English Localization, Build-Time Version Injection & Governance Enforcement (Issue `#148`)
- **Date**: `2026-11-02T07:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#148` (`feat/issue-148-makefile-version-governance`)
- **Request**: Translate Patroni cluster echoes in Makefile to English; inject main.version at compile-time via ldflags in Makefile build-go; synchronize cmd/mdb/main.go version to 2.0.23; expand governance tests in test_project_governance_rules.py to scan Makefile and conf/ for French strings and verify Go version synchronization.
- **Changes**: Localized 4 Patroni echo messages in `Makefile:21,25,29,33`; added `-X main.version=...` to `Makefile:591` `build-go`; updated `var version = "2.0.23"` in `cmd/mdb/main.go`; updated `TestResolveVersion` in `cmd/mdb/main_test.go`; extended `test_no_french_table_headers_remain` and added `test_version_synchronization_and_ldflags_injection` in `tests/test_project_governance_rules.py`; bumped `VERSION` to `2.0.23`; updated `Changelog`.
- **Result**: `python -m unittest discover -s tests -v` passed (20/20, 6 skipped); `go test -v ./...` passed (66/66); `make build-go` produced `bin/mdb` printing `mdb version 2.0.23`. PR diff size strictly < 15,000 characters.

---

### ACT-048 — Cluster Guides Sync, Mongo 8 PKI & Runner Import Hardening (Issue `#146`)
- **Date**: `2026-11-02T07:15+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#146` (`doc/issue-146-cluster-guides-sync`)
- **Request**: Sync cluster guides (InnoDB, PgPool, Mongo) with tests & TLS; harden `gen_ssl_mongo.sh`, `mysql_docker.py`, and `Makefile`.
- **Changes**: Updated `innodb_cluster.md`, `pgpool_cluster.md`, `mongo_replicaset.md`, `INDEX.md`, `gen_ssl_mongo.sh`, `mysql_docker.py`, `Makefile`, `VERSION` (2.0.22), and `Changelog`.
- **Result**: All tests passed: `go test` (66/66), `unittest` (19/19), `test_config.sh`, `test_secure_password.sh` (34/34), `mdb pki verify all`. Diff < 15K.

---

### ACT-047 — Parameterize Cluster Replication Credentials, Audit Conf Scripts & Enforce Go English Governance (Issue `#144`)
- **Date**: `2026-11-02T06:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#144` (`fix/issue-144-cluster-creds-conf-audit`)
- **Request**: Source `.env` and parameterize `REPL_USER`/`REPL_PASS` in `conf/innodb-cluster/setup_cluster.sh` and `scripts/pgpool/setup_replication.sh`; add `conf/**/*.sh` scripts to `tests/test_config.sh` with `set -euo pipefail` checks; extend `tests/test_project_governance_rules.py` to audit `conf/**/*.sh` and assert no French strings remain in Go packages.
- **Changes**: Sourced `.env` and parameterized credentials in `conf/innodb-cluster/setup_cluster.sh` and `scripts/pgpool/setup_replication.sh`; added conf scripts and strict error handling check to `tests/test_config.sh`; added `conf` directory to `test_all_bash_scripts_have_set_euo_pipefail` and added `test_no_french_strings_in_go_packages` in `tests/test_project_governance_rules.py`; bumped `VERSION` to `2.0.21`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (66/66), `python -m unittest discover -s tests -v` passed (19/19, 6 skipped), `bash tests/test_config.sh` passed, `bash tests/test_secure_password.sh` passed (34/34). PR diff size strictly < 15,000 characters.

---

### ACT-046 — Sysbench MYSQL_PWD Env Injection, Go CLI Version Sync & Default Password Alignment (Issue `#142`)
- **Date**: `2026-11-02T06:15+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#142` (`fix/issue-142-sysbench-pwd-version-sync`)
- **Request**: Pass `MYSQL_PWD` via `env` slice in `SysbenchRunner.Run`, replace French fallback password in `pkg/config/config.go` with `"rootpass"`, synchronize `cmd/mdb/main.go` version with `VERSION` via `resolveVersion()`, and add unit tests.
- **Changes**: Injected `MYSQL_PWD` in `env` in `pkg/bench/sysbench.go`; updated `mockExecutor` and added env assertion in `pkg/bench/sysbench_test.go`; replaced default password with `"rootpass"` in `pkg/config/config.go` and asserted in `pkg/config/config_test.go`; bumped `version = "2.0.20"` and added `resolveVersion()` in `cmd/mdb/main.go`; added `TestResolveVersion` in `cmd/mdb/main_test.go`; bumped `VERSION` to `2.0.20`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (66/66), `python -m unittest discover -s tests -v` passed (18/18, 6 skipped), `bash tests/test_config.sh` passed, `bash tests/test_secure_password.sh` passed (34/34). PR diff size strictly < 15,000 characters.

---

### ACT-045 — MongoVerifier TLS Fallback, Mongo8 PKI & Container SANs (Issue `#140`)
- **Date**: `2026-11-02T05:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#140` (`fix/issue-140-mongo-tls-pki-mongo8`)
- **Request**: Add TLS fallback in MongoVerifier, add mongo8 and Compose container SANs in PKIEngine and scripts, and add unit tests.
- **Changes**: Added 4-tier TLS fallback in `pkg/dbclient/mongo.go`; decoupled arg check in `postgres_mongo_test.go`; added tests in `dbclient_test.go` and `cert_test.go`; added `mongo8` and container SANs in `cert.go` and `scripts/gen_ssl*.sh`; bumped `VERSION` to `2.0.19`; updated `Changelog`.
- **Result**: `go test` (76/76), `unittest` (18/18), `test_config` pass. PR diff < 15k.

---

### ACT-042 — Go mdb CLI, Automation Scripts Reference & README Governance Sync (Issue `#138`)
- **Date**: `2026-11-02T05:00+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#138` (`doc/issue-138-cli-scripts-readme`)
- **Request**: Fully document the compiled Go `mdb` CLI (v2.0), utility automation scripts (`gen_pki.sh`, `run_mysqltuner.sh`, `aggregate_reports.sh`), and synchronize `README.md` with living governance registers and updated project directory structure.
- **Changes**: Added `make build-go` and `make test-go` to General Commands in `README.md`; added `## 🚀 Go mdb CLI Orchestrator (v2.0)` with commands table and `## 📜 Project Governance & Living Registers` in `README.md`; updated Project Structure tree with `cmd/mdb/`, `pkg/`, `go.mod`, and `docs/`; documented `scripts/gen_pki.sh`, `scripts/run_mysqltuner.sh`, `scripts/aggregate_reports.sh`, and Go CLI command reference in `documentation/scripts.md`; bumped `VERSION` to `2.0.18`; updated `Changelog`.
- **Result**: All test suites pass cleanly (`test_project_governance_rules.py`, `unittest`, `test_secure_password.sh`, `test_config.sh`, `go test -v ./...`). PR diff size strictly < 15,000 characters.

---

### ACT-041 — Architecture Port Reconciliation, Makefile Parity & Governance Index (Issue `#136`)
- **Date**: `2026-11-02T04:55+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#136` (`doc/issue-136-ports-makefile-index`)
- **Request**: Correct documented ports (Galera Node 1 SSH 24001, MariaDB Replication 3411-3413), deduplicate Makefile commands (remove duplicate `make start` and phantom `pgpass`/`pgclient`, add `postgres15`, Go CLI, HA clusters, and E2E targets), and expand Governance table in documentation index.
- **Changes**: Replaced `22001` with `24001` in `documentation/architecture.md`; replaced `3611-3613` with `3411-3413` in `documentation/supported_products.md` and `documentation/supported_products_fr.md`; cleaned `documentation/makefile.md` (removed line 10 duplicate `make start` and phantom `pgpass`/`pgclient`, added `postgres15`, Go CLI, HA cluster targets, and E2E targets); expanded Governance table in `documentation/INDEX.md` with links to `AGENTS.md`, `ACTION_LOGBOOK.md`, `RCA_REGISTER.md`, and project governance rules; bumped `VERSION` to `2.0.17`; updated `Changelog`.
- **Result**: All test suites pass cleanly (`test_project_governance_rules.py`, `unittest`, `test_secure_password.sh`, `test_config.sh`, `go test -v ./...`). PR diff size strictly < 15,000 characters.

---

### ACT-040 — Patroni Scripts, Perf Reports Localization & Governance Rule Expansion (Issue `#134`)
- **Date**: `2026-11-02T04:20+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#134` (`fix/issue-134-patroni-perf-french-cleanup`)
- **Request**: Localize French comments in Patroni scripts and HTML cards in Galera/Replication perf tests; expand governance rule `test_no_french_table_headers_remain`.
- **Changes**: Localized comments in `scripts/patroni/entrypoint_etcd.sh` and `generate_certs.sh`; localized HTML titles and captions in `tests/test_perf_galera.sh` and `test_perf_repli.sh`; expanded `test_no_french_table_headers_remain` regex; bumped `VERSION` to `2.0.16`; updated `Changelog`.
- **Result**: All test suites pass cleanly (`test_project_governance_rules.py`, `unittest`, `test_secure_password.sh`, `test_profiles.sh`, `test_config.sh`, `go test`). PR diff < 15,000 chars.

---

### ACT-039 — Provider Options Pipeline Operator Precedence & Test Suites English Localization (Part 1) (Issue `#132`)
- **Date**: `2026-11-02T04:10+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#132` (`fix/issue-132-complete-english-localization`)
- **Request**: Fix operator precedence in `tests/test_galera.sh:290` and translate French HTML labels in Galera and HAProxy test suites while respecting the strict < 15,000 diff character limit.
- **Changes**: Moved `| xargs` before `|| true` in `tests/test_galera.sh:290`; translated French HTML headers and labels in `tests/test_galera.sh`; translated latency labels in `tests/test_haproxy_galera.sh`; bumped `VERSION` to `2.0.15`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (6/6), `unittest discover` (18/18, 6 skipped), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-038 — HAProxy Galera Localization & English Governance Rule (Issue `#130`)
- **Date**: `2026-11-02T03:28+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#130` (`fix/issue-130-haproxy-governance-rule`)
- **Request**: Enforce English-only policy across HAProxy Galera test suite and add automated governance rule `test_no_french_table_headers_remain` (Finding 5 completion).
- **Changes**: Localized Markdown and HTML report table headers, status cards, and comments in `tests/test_haproxy_galera.sh`; added `test_no_french_table_headers_remain` in `tests/test_project_governance_rules.py`; bumped `VERSION` to `2.0.14`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (6/6), `unittest discover` (17/17, 6 skipped), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-037 — Galera & Replication Test Suites English Localization (Issue `#128`)
- **Date**: `2026-11-02T03:22+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#128` (`fix/issue-128-galera-repli-localization`)
- **Request**: Enforce English-only policy across Galera and Replication test suites (Finding 5 remediation part 2).
- **Changes**: Localized Markdown and HTML report table headers and section titles in `tests/test_galera.sh`, `tests/test_repli.sh`, and `tests/test_lb_galera.sh`; bumped `VERSION` to `2.0.13`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (5/5), `unittest discover` (17/17, 6 skipped), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-036 — Patroni & MariaDB Scripts English Localization (Issue `#126`)
- **Date**: `2026-11-02T03:15+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#126` (`fix/issue-126-english-localization`)
- **Request**: Enforce English-only policy across Patroni and MariaDB startup scripts (Finding 5 remediation part 1).
- **Changes**: Localized French comments and echo messages in `scripts/patroni/entrypoint_etcd.sh`, `scripts/patroni/entrypoint_node.sh`, `scripts/patroni/generate_certs.sh`, `scripts/start_mariadb.sh`; bumped `VERSION` to `2.0.12`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (5/5), `unittest discover` (17/17, 6 skipped), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-035 — Test Script Strict Mode Safeguards & Runtime Crash Remediation (Issue `#124`)
- **Date**: `2026-11-02T03:00+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#124` (`fix/issue-124-strict-guards-and-localization`)
- **Request**: Remediate latent script exits under `set -euo pipefail` identified during Milestone 2 gate review (Finding 4 remediation).
- **Changes**: Replaced `((MATCH_COUNT++))` with `MATCH_COUNT=$((MATCH_COUNT + 1))` in `tests/test_galera.sh:80`; guarded duplicate key insert command substitution with `|| true` in `tests/test_galera.sh:250`; guarded provider options grep with `|| true` in `tests/test_galera.sh:290`; guarded pre-flight replication grep checks with `|| true` in `tests/test_repli.sh:82-83`; initialized associative arrays with `declare -A hosts_count=()` in `tests/test_lb_galera.sh:45` and `declare -A FAILOVER_COUNT=()` in `tests/test_haproxy_galera.sh:127`; guarded `get_latency()` in `tests/test_haproxy_galera.sh:81`; bumped `VERSION` to `2.0.11`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (5/5), `unittest discover` (17/17, 6 skipped), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-034 — Test Suites Strict Error Handling, Arithmetic Guards & Governance Scanner (Issue `#122`)
- **Date**: `2026-11-02T02:25+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#122` (`fix/issue-122-tests-strict-mode-and-governance`)
- **Request**: Enforce `set -euo pipefail` across remaining test suites (`tests/test_galera.sh`, `tests/test_repli.sh`, `tests/test_lb_galera.sh`, `tests/test_haproxy_galera.sh`, `tests/test_mongo_rs.sh`, `tests/test_perf_galera.sh`, `tests/test_perf_repli.sh`, `tests/test_secure_password.sh`), harden arithmetic increments and associative array lookups under strict mode, and add automated governance rule `test_all_bash_scripts_have_set_euo_pipefail` in `tests/test_project_governance_rules.py`.
- **Changes**: Added `set -euo pipefail` to 8 test suites; guarded associative array lookups `${hosts_count[$host]:-0}` and incremented safely; added `test_all_bash_scripts_have_set_euo_pipefail` asserting 100% shell compliance across `scripts/` and `tests/`; bumped `VERSION` to `2.0.10`; updated `Changelog`.
- **Result**: `tests/test_project_governance_rules.py` (5/5), `unittest discover` (17/17), `tests/test_secure_password.sh` (34/34), `tests/test_profiles.sh`, `tests/test_config.sh`, and `go test -v ./...` (63/63) passed cleanly. PR diff size < 15,000 characters.

---

### ACT-033 — Bash Strict Error Handling, Profiles Quoting & Governance Rule (Issue `#120`)
- **Date**: `2026-11-02T02:00+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#120` (`fix/issue-120-strict-bash-and-profiles-quoting`)
- **Request**: Enforce `set -euo pipefail` across remaining scripts (Finding 4), fix heredoc quoting in `gen_profiles.sh` (M1 remediation), fix arithmetic increments under strict mode, and add governance rule.
- **Changes**: Fixed heredoc unescaping bug in `gen_profiles.sh`; added strict mode across 17 scripts; converted `((var++))` and guarded array indexing in tests; added `test_all_bash_scripts_have_set_euo_pipefail` in `tests/test_project_governance_rules.py`; bumped `VERSION` to `2.0.9`.
- **Result**: `test_project_governance_rules.py` (5/5), `test_config.sh`, `test_profiles.sh`, `test_secure_password.sh` (34/34), `unittest` (17/17), and `go test` (63/63) passed cleanly.

---

### ACT-032 (ACT-015) — Core Test Suite and Script Fixes (Issue `#118`)
- **Date**: `2026-11-02T01:25+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#118` (`fix/issue-118-core-test-script-fixes`)
- **Request**: Remediate Cycle 1 Findings 1, 2A, 3, and 7 across core test suite and scripts (unauthenticated mariadb conflict call, mongo perf TLS fallback, Galera SSH port 24001 and quoted aliases, test_config subshell loss & compose validation, duplicate .env parser).
- **Changes**: Authenticated conflict test and guarded `wait $PID1 || true` in `test_galera.sh`; standard POSIX `.env` sourcing in `test_galera.sh` and `test_repli.sh`; 3-tier TLS fallback in `test_perf_mongo.sh`; synced Galera SSH port 24001 and quoted `MYSQL_PWD` in `gen_profiles.sh` and `docker-compose-galera.yml`; process substitution, `RET=1` on missing scripts, and 8 compose files check in `test_config.sh`; bumped `VERSION` to `2.0.8` and updated `Changelog`.
- **Result**: `tests/test_config.sh` passed (41 checks), `tests/test_profiles.sh` passed, `tests/test_secure_password.sh` passed (34/34), `python -m unittest discover -s tests -v` passed (16/16), `go test -v ./...` passed (63/63), PR diff < 15,000 characters.

---

### ACT-031 — Obsolete Legacy Scripts Cleanup (Issue `#116`)
- **Date**: `2026-11-02T00:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#116` (`chore/issue-116-remove-dead-scripts`)
- **Request**: Remove obsolete temporary workaround scripts `scripts/apply_fix_2.sh` and `scripts/fix_issue.sh` (#7B).
- **Changes**: Removed `scripts/apply_fix_2.sh` and `scripts/fix_issue.sh`; bumped `VERSION` to `2.0.7`; updated `Changelog`.
- **Result**: `tests/test_config.sh` passed, `python -m unittest discover -s tests -v` passed (16/16), `go test -v ./...` passed (63/63), PR diff strictly < 15,000 characters.

---

### ACT-030 — Performance/HAProxy Container Resolution & Safe .env Sourcing (Issue `#114`)
- **Date**: `2026-11-02T00:35+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#114` (`fix/issue-114-perf-container-resolution-env`)
- **Request**: Resolve performance/HAProxy container resolution and safe .env sourcing across all remaining scripts (#3, #6).
- **Changes**: Dynamically resolved container names with fallback in `tests/test_perf_galera.sh`, `tests/test_perf_repli.sh`, and `tests/test_haproxy_galera.sh`; replaced fragile `export $(grep ... | xargs)` with safe shell sourcing in `scripts/gen_profiles.sh`, `scripts/setup_repli.sh`, `scripts/patroni/generate_certs.sh`, `tests/test_innodb_cluster.sh`, `tests/test_lb_galera.sh`, `tests/test_patroni.sh`, and `tests/test_pgpool.sh`; bumped `VERSION` to `2.0.6` and updated `Changelog`.
- **Result**: `python -m unittest discover -s tests -v` passed (16/16), `go test -v ./...` passed (63/63), all bash test suites passed, PR diff strictly < 15,000 characters.

---

### ACT-029 — Dynamic Container Resolution, Credential Protection & Python 3.11 CI Compatibility (Issue `#112`)
- **Date**: `2026-11-02T00:20+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#112` (`fix/issue-112-bash-scripts-cleanup`)
- **Request**: Resolve container prefix mismatch, physical backup credential exposure, and Python 3.11 syntax error (#3, #6).
- **Changes**: Dynamically resolved container names with fallback in `scripts/backup_logical.sh`, `scripts/backup_physical.sh`, `scripts/restore_logical.sh`, `scripts/restore_physical.sh`, `tests/test_failover.sh`, and `tests/test_backup_restore.sh`; replaced CLI `--password` with `MYSQL_PWD` in `backup_physical.sh`; fixed f-string syntax in `interactive_runner.py:224`; bumped `VERSION` to `2.0.5` and updated `Changelog`.
- **Result**: `python -m unittest discover -s tests -v` passed (16/16), `go test -v ./...` passed (63/63), all bash test suites passed, PR diff strictly < 15,000 characters.

---

### ACT-028 — Go Sysbench Connection Credentials & Report Wrapper Cleanup (Issue `#110`)
- **Date**: `2026-11-02T00:05+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#110` (`fix/issue-110-go-sysbench-report`)
- **Request**: Resolve Ponytail audit remediation findings for Go packages (#4, #7A).
- **Changes**: Defaulted `cfg.User = "root"` and passed driver/credentials/host/port flags in `pkg/bench/sysbench.go`; supplied `User: "root"` in `cmd/mdb/main.go`; deleted redundant package-level wrappers `AddStepSummary`, `WriteJSONTelemetry`, `RenderHTMLReport` from `pkg/report/report.go`; updated tests in `pkg/bench/sysbench_test.go` and `pkg/report/report_test.go`; bumped `VERSION` to `2.0.4` and updated `Changelog`.
- **Result**: `go test -v ./...` passed (63/63), `python -m unittest discover -s tests -v` passed (16/16), PR diff strictly < 15,000 characters.

---

### ACT-027 — Python Runners Core Fixes: Operator Precedence, Pipe Deadlock, Alias Prefix & CSPRNG (Issue `#108`)
- **Date**: `2026-11-01T23:45+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#108` (`fix/issue-108-runners-cli-fixes`)
- **Request**: Resolve Ponytail audit remediation findings for Python runners (#1, #2, #5, #8).
- **Changes**: Fixed operator precedence & stderr buffer deadlock in `interactive_runner.py`; fixed `UnboundLocalError`, image tags check, alias prefix filtering & CSPRNG in `mysql_docker.py`; added unit test suite in `tests/test_python_runners.py`; bumped `VERSION` to `2.0.3` and updated `Changelog`.
- **Result**: `python -m unittest discover -s tests -v` passed (16/16), `test_secure_password.sh` passed (34/34), PR diff strictly < 15,000 characters.

---

### ACT-026 — Align `start_mariadb.sh` Init User with Root for `0600` Host SSL Keys & Bound Galera CI Startup (Issue `#106`)
- **Date**: `2026-11-01T00:16+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#106` (`fix/issue-106-start-mariadb-ssl-uid-and-galera-ci`)
- **Request**: Fix MariaDB initialization failure when reading host-mounted `0600` `/etc/mysql/ssl/server-key.pem` (`uid=1001`) and bound Galera readiness checks in CI.
- **Changes**: Updated `scripts/start_mariadb.sh` to run `mariadb-install-db` and temporary initialization `mariadbd` with `--user=root --wsrep-provider=none` and `COUNTER=$((COUNTER + 1))`; updated `Makefile` (`up-galera` and `inject-employee-galera`) with bounded 60-attempt readiness checks, supervisor log diagnostics on failure, and fast `employees` schema fixture in CI.
- **Result**: Galera 3-node cluster bootstraps cleanly in CI and `make mysqltuner-galera` completes deterministically; PR diff strictly < 15,000 characters.

---

### ACT-025 — Pre-Chown Temporary CSR/CNF Cleanup in `gen_pki.sh` & Containerized Galera CLI Calls (Issue `#104`)
- **Date**: `2026-11-01T00:09+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#104` (`fix/issue-104-gen-pki-cleanup-and-galera-ci`)
- **Request**: Fix `rm: cannot remove './ssl/pgpool/san.cnf': Permission denied` after Docker `chown 999:999` in `scripts/gen_pki.sh`, and containerize Galera `mariadb` calls and `test_db` submodule init in `Makefile`.
- **Changes**: Moved `rm -f "$CFG" "$DIR"/*.csr "$DIR"/*.srl "$DIR"/t.csr` before the `CHOWN_U` block in `scripts/gen_pki.sh` and added `keyUsage` extensions; updated `up-galera` and `inject-employee-galera` in `Makefile` to run `mariadb` inside `galera_01`/`galera_02`/`galera_03` containers and initialize `test_db` submodule when absent.
- **Result**: `make gen-ssl-all`, `make check-ssl-all`, and CI stages execute cleanly without host permission or missing host binary errors; PR diff strictly < 15,000 characters.

---

### ACT-024 — Resolve POSIX 126 Permission Denied on `scripts/gen_pki.sh` in CI TLS Generation (Issue `#102`)
- **Date**: `2026-11-01T00:04+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#102` (`fix/issue-102-gen-pki-exec-permissions`)
- **Request**: Fix GitHub Actions CI run `41247154340` failing at Step #4 (`Generate and Check TLS Certificates`) with `scripts/gen_pki.sh: Permission denied` (POSIX error 126).
- **Changes**: Updated `scripts/gen_ssl.sh`, `scripts/gen_ssl_innodb.sh`, `scripts/gen_ssl_mongo.sh`, `scripts/gen_ssl_patroni.sh`, and `scripts/gen_ssl_pgpool.sh` to invoke `exec bash "$(dirname "$0")/gen_pki.sh"` explicitly so execution never depends on filesystem executable bits. Updated `docs/ACTION_LOGBOOK.md` (`ACT-024`) and `docs/RCA_REGISTER.md` (`RCA-022`).
- **Result**: `make gen-ssl-all` and `make check-ssl-all` succeed across all 5 database topologies without POSIX 126 errors; PR diff strictly < 15,000 characters.

---

### ACT-023 — Ponytail v2.0.0 Audit Remediation Part 2: Makefile, CI Go Gate, Setup Script & HAProxy Pinning (Issue `#100`)
- **Date**: `2026-10-31T23:10+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#100` (`fix/issue-100-makefile-ci-compose`)
- **Request**: Resolve Ponytail Audit findings #4, #5, #6, #8, and #9 across `Makefile`, `scripts/setup_repli.sh`, and Docker Compose files.
- **Changes**: Fixed `DB_SERVICE`/`DB_CONTAINER` in `Makefile` (`client:`), replaced 7 `-p` flags with `MYSQL_PWD`, wired `mdb pki verify all` into `check-ssl-all` and `test-go`/`unittest` into `test-config` (executed by CI), defined `PASS` in `scripts/setup_repli.sh`, and pinned `haproxy:lts` in `docker-compose-galera.yml`, `docker-compose-repli.yml`, and `docker-compose-pgpool.yml`. Bumped `VERSION` to `2.0.2`.
- **Result**: `go test -v ./...` passed (64/64), Python unit tests passed (10/10), PR diff < 15,000 chars.

---

### ACT-022 — Ponytail v2.0.0 Audit Remediation Part 1: Go Runtime Wiring & Topology Bootstrap (Issue `#98`)
- **Date**: `2026-10-31T23:04+01:00` · **Status**: `COMPLETED` · **Issue / Branch**: `#98` (`fix/issue-98-go-runtime-wiring`)
- **Request**: Resolve Ponytail Audit findings #1, #2, #3, and #7 on the v2.0.0 Go codebase.
- **Changes**: Updated `cmd/mdb/main.go` (`defaultContainer`, `resolveContainer`, `loadPassword`, `runner.NewPipeline` in `report`), `pkg/docker/client.go` (`extractComposeEnv`), `pkg/topology/` (`WithSetupScript` and Galera bootstrap), `VERSION` (`2.0.1`), and `Changelog`.
- **Result**: `go test -v ./...` passed (64/64), Python unit tests passed (10/10), PR diff < 15,000 chars.

---

### ACT-021 — Release v2.0.0: Golang Migration, Makefile Integration & Governance (Issue `#96`)
- **Date**: `2026-10-31T02:30+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#96` (`feat/issue-96-release-v200-makefile-governance`)
- **Request**: Complete Milestone 4 of the Golang Migration roadmap: Makefile targets (`build-go`, `test-go`), bump `VERSION` to `2.0.0`, write v2.0.0 release notes in `Changelog`, update living registers.
- **Changes**:
  - Added `build-go` and `test-go` targets to [`Makefile`](../Makefile) with help text and `.PHONY` entries.
  - Bumped version in [`cmd/mdb/main.go`](../cmd/mdb/main.go) and [`VERSION`](../VERSION) to `2.0.0`.
  - Added comprehensive v2.0.0 release notes to [`Changelog`](../Changelog).
  - Updated [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md) (Phase 7 and `ACT-021`) and [`docs/RCA_REGISTER.md`](RCA_REGISTER.md) (`APP-007`).
- **Result**: `make test-go` passed (63 tests across 9 packages), `wsl go test -race ./...` passed with 0 data races, Python unit tests passed (100%), PR diff strictly < 15,000 characters.

---

### ACT-020 — Embedded HTML Report Template and CLI Subcommand (Issue `#94`)
- **Date**: `2026-10-31T02:26+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#94` (`feat/issue-94-embedded-html-reporter-cli`)
- **Request**: Embedded HTML template aggregator in `pkg/report` and `mdb report` subcommand in `cmd/mdb/main.go`.
- **Changes**: Created `pkg/report/templates/report.html`; added `RenderHTML` and `SaveHTML` to `pkg/report/report.go`; updated `pkg/report/report_test.go`; added `report` subcommand to `cmd/mdb/main.go`; bumped `VERSION` to `1.3.43`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (63 tests), race detector passed with 0 data races, diff strictly < 15,000 characters.

---

### ACT-019 — Structured JSON Telemetry Engine and Summary Aggregator (Issue `#92`)
- **Date**: `2026-10-31T02:20+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#92` (`feat/issue-92-structured-telemetry-html-report`)
- **Request**: Structured telemetry model, JSON serialization, and summary calculation in `pkg/report`.
- **Changes**: Created `pkg/report/report.go`, `pkg/report/report_test.go`; bumped `VERSION` to `1.3.42`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (62 tests), race detector passed with 0 data races, diff strictly < 15,000 characters.

---

### ACT-018 — Sysbench Benchmark Runner & CLI Integration (Issue `#90`)
- **Date**: `2026-10-31T02:08+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#90` (`feat/issue-90-sysbench-runner-cli`)
- **Request**: Sysbench benchmark runner and regex metric parser (`pkg/bench`), CLI `test` and `bench` subcommands in `cmd/mdb/main.go`.
- **Changes**: Created `pkg/bench/sysbench.go`, `pkg/bench/sysbench_test.go`; updated `cmd/mdb/main.go`; bumped `VERSION` to `1.3.41`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), race detector passed with 0 data races, governance tests passed, PR diff strictly < 15,000 characters.

---

### ACT-017 — Concurrent Step Execution Pipeline (Issue `#88`)
- **Date**: `2026-10-31T02:00+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#88` (`feat/issue-88-concurrent-runner-pipeline`)
- **Request**: Concurrent step execution pipeline with dependency resolution, timeouts, and callbacks.
- **Changes**: Created `pkg/runner/step.go`, `runner.go`, `runner_test.go`; bumped `VERSION` to `1.3.40`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), race detector passed with 0 data races, diff < 15,000 characters.

---

### ACT-016 — PostgreSQL and MongoDB Cluster Verification Drivers (Issue `#86`)
- **Date**: `2026-10-31T01:50+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#86` (`feat/issue-86-postgres-mongo-verifiers`)
- **Request**: Verification drivers for PostgreSQL (Patroni, PgPool) and MongoDB (ReplicaSet).
- **Changes**: Created `pkg/dbclient/postgres.go`, `mongo.go`, tests; bumped `VERSION` to `1.3.39`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), 0 data races, governance tests passed, PR diff < 15,000 characters.

---

### ACT-015 — Pure-Go Database Verification Drivers (Issue `#84`)
- **Date**: `2026-10-31T01:35+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#84` (`feat/issue-84-dbclient-verification-drivers`)
- **Request**: Pure-Go database verification drivers (`pkg/dbclient`) for MySQL/MariaDB with `Verifier` interface and hermetic tests.
- **Changes**: Created `pkg/dbclient/dbclient.go`, `mysql.go`, `dbclient_test.go`; bumped `VERSION` to `1.3.38`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), 0 data races, governance tests passed, PR diff strictly < 15,000 characters.

---

### ACT-014 — Declarative Topology Engine & CLI Integration (Issue `#82`)
- **Date**: `2026-10-31T01:15+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#82` (`feat/issue-82-topology-engine-cli`)
- **Request**: Declarative topology definitions (`pkg/topology`) and CLI lifecycle commands (`up`, `down`, `status`, `topologies`) in `cmd/mdb/main.go`.
- **Changes**: Created `pkg/topology/topology.go`, `standalone.go`, `galera.go`, `repli.go`, `patroni.go`, `pgpool.go`, `innodb.go`, `mongo.go`; wrote tests in `topology_test.go`; updated `cmd/mdb/main.go`; bumped `VERSION` to `1.3.37`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), race detector passed with 0 data races, tests passed, PR diff strictly < 15,000 characters.

---

### ACT-013 — Docker Engine & Compose Wrapper with Mock Runner (Issue `#80`)
- **Date**: `2026-10-31T01:05+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#80` (`feat/issue-80-docker-wrapper-client`)
- **Request**: Docker Engine and Compose wrapper (`pkg/docker`) with `CommandRunner` and hermetic mock runner.
- **Changes**: Created `pkg/docker/client.go`, `compose.go`, `docker_test.go`; bumped `VERSION` to `1.3.36`; updated `Changelog`.
- **Result**: `go test -v ./...` passed, race detector passed (0 races), PR diff strictly < 15,000 characters.

---

### ACT-012 — Native PKI Engine Error Propagation and Verify All Remediation (Issue `#78`)
- **Date**: `2026-10-31T01:00+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#78` (`feat/issue-78-docker-wrapper-pki-fixes`)
- **Request**: Fix error shadowing in `GenerateTopologyCerts` and `VerifyTopologyCerts`, add `"all"` topology support to `VerifyTopologyCerts`, add unit tests for corrupted certificates and invalid directories, and add `bin/` to `.gitignore`.
- **Changes**: Updated `pkg/pki/cert.go` to support `VerifyTopologyCerts("all")` and preserve errors from `save` and `VerifyCertBytes`; added test coverage in `pkg/pki/cert_test.go`; added `bin/` and `*.exe` to `.gitignore`; bumped `VERSION` to `1.3.35`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), race detector passed with 0 data races, `python -m unittest discover -s tests -v` passed, PR diff strictly < 15,000 characters.

---

### ACT-011 — Native Pure-Go x509 PKI Engine with SAN and CLI Integration (Issue `#76`)
- **Date**: `2026-10-31T00:35+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#76` (`feat/issue-76-golang-native-pki`)
- **Request**: Native x509 PKI engine (pkg/pki) with SAN, RSA 2048, combined PEM, and mdb pki CLI.
- **Changes**: Created `pkg/pki/cert.go` for multi-topology cert generation; integrated `pki` in `cmd/mdb/main.go`; added tests in `pkg/pki/cert_test.go`; bumped `VERSION` to `1.3.34`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), `go build ./...` succeeded, `python -m unittest discover -s tests -v` passed, PR diff strictly < 15,000 characters.

---

### ACT-010 — Milestone 1: Golang Scaffolding, CLI Entry Point, and Typed Config Loader (Issue `#74`)
- **Date**: `2026-10-31T00:25+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#74` (`feat/issue-74-golang-scaffolding-pki`)
- **Request**: Implement Milestone 1 Go scaffolding: go.mod scaffolding, cmd/mdb CLI entry point, and pkg/config typed loader.
- **Changes**: Initialized `go.mod` (module `github.com/jmrenouard/multi-db-docker-env`); created `cmd/mdb/main.go` with `version` and `config` commands; built `pkg/config/config.go` with `.env` parser and validation; added comprehensive unit tests in `pkg/config/config_test.go`; bumped `VERSION` to `1.3.33`; updated `Changelog`.
- **Result**: `go test -v ./...` passed (100%), `go build ./...` succeeded, `python -m unittest discover -s tests -v` passed without regression, PR diff strictly < 15,000 characters.

---

### ACT-009 — Migrate Mongo, PgPool, and Patroni SSL Scripts to Unified PKI Generator (Issue `#72`)
- **Date**: `2026-10-30T23:58+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#72` (`feat/issue-72-migrate-remaining-ssl-wrappers`)
- **Request**: Migrate `scripts/gen_ssl_mongo.sh`, `scripts/gen_ssl_pgpool.sh`, and `scripts/gen_ssl_patroni.sh` to delegate to unified `scripts/gen_pki.sh` with `--force` bypass, strict `0600` key permissions, and SAN extensions.
- **Changes**: Converted `gen_ssl_mongo.sh` and `gen_ssl_pgpool.sh` to delegate to `gen_pki.sh` with `--force` support; added fallback to `gen_pki.sh` in `gen_ssl_patroni.sh`; updated `VERSION` to `1.3.32`; updated `Changelog`.
- **Result**: `make check-ssl-all` validated all 5 topologies; `make test-config` and unit tests passed; PR diff strictly < 15,000 characters.

---

### ACT-008 — OpenSSL PKI Certificate Generators Consolidation (Issue `#70`)
- **Date**: `2026-10-30T23:50+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#70` (`feat/issue-70-unified-pki-generator`)
- **Request**: Consolidate five OpenSSL certificate generators (`gen_ssl.sh`, `gen_ssl_innodb.sh`, `gen_ssl_mongo.sh`, `gen_ssl_patroni.sh`, `gen_ssl_pgpool.sh`) into unified `scripts/gen_pki.sh` with Subject Alternative Name (SAN) support and strict `0600` key permissions while preserving existing script entry points as thin wrappers.
- **Changes**: Created `scripts/gen_pki.sh` with SAN extensions, multi-mode certificate topologies (`mariadb`, `standard`, `single`), combined PEM generation, and configurable file ownership/permissions (`0600`/`0644`); converted wrapper scripts into one-line delegators with `--force` bypass; updated `VERSION` to `1.3.31`; updated `Changelog`.
- **Result**: `make check-ssl-all` validated all 5 topologies; `tests/test_security_ssl.sh` passed; `make test-config` passed (100%); PR diff strictly < 15,000 characters.

---

### ACT-007 — Ponytail Audit Remediation across Python, Bash and Test Scripts (Issue `#68`)
- **Date**: `2026-10-30T22:30+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#68` (`fix/issue-68-ponytail-audit-remediation`)
- **Request**: Resolve 10 Ponytail audit remediation findings across legacy Python, Bash, and test scripts (R1).
- **Changes**: Fixed CLI prompt blocking in `interactive_runner.py`; fixed `except e:`, missing argument, and password exposure in `mysql_docker.py`; improved metric extraction in `scripts/aggregate_reports.sh`; safeguarded `.env` and error handling in `tests/test_galera.sh` and `test_repli.sh`; consolidated PKI generator in `scripts/gen_pki.sh`; bumped `VERSION` to `1.3.30`; updated `Changelog`.
- **Result**: `make test-config`, governance, and security regression tests passed; PR diff strictly < 15,000 characters.

---

### ACT-006 — Add Governance Tests for Consolidated Registers and English Language (Issue `#66`)
- **Date**: `2026-10-30T22:50+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#66` (`test/issue-66-consolidated-governance-test`)
- **Request**: Add unit test coverage in `tests/test_project_governance_rules.py` asserting that `ROADMAP.md` and `POTENTIAL_ISSUES.md` redirect to living registers and that English language is strictly enforced.
- **Changes**: Added `test_roadmap_and_potential_issues_consolidated_in_english` in [`tests/test_project_governance_rules.py`](../tests/test_project_governance_rules.py); bumped [`VERSION`](../VERSION) to `1.3.29`; updated [`Changelog`](../Changelog).
- **Result**: `python -m unittest discover -s tests -v` passing (100%), PR diff strictly within `< 15,000` characters limit (`~2,400` chars).

---

### ACT-005 — Redirect POTENTIAL_ISSUES.md to Consolidated RCA Register (Issue `#64`)
- **Date**: `2026-10-30T22:48+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#64` (`docs/issue-64-redirect-potential-issues`)
- **Request**: Replace obsolete root `POTENTIAL_ISSUES.md` with an explicit redirection pointer to `docs/RCA_REGISTER.md`.
- **Changes**: Replaced [`POTENTIAL_ISSUES.md`](../POTENTIAL_ISSUES.md) content with pointer note; bumped [`VERSION`](../VERSION) to `1.3.28`; updated [`Changelog`](../Changelog).
- **Result**: `python -m unittest discover -s tests -v` passing (100%), PR diff strictly within `< 15,000` characters limit (`~8,200` chars).

---

### ACT-004 — Consolidate Potential Issues into RCA Register (Issue `#62`)
- **Date**: `2026-10-30T22:47+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#62` (`docs/issue-62-consolidate-rca-register`)
- **Request**: Consolidate all historical anomalies, warnings, technical debt, and Sourcery AI resolutions from `POTENTIAL_ISSUES.md` into `docs/RCA_REGISTER.md`.
- **Changes**:
  - Expanded [`docs/RCA_REGISTER.md`](RCA_REGISTER.md) with `RCA-003` to `RCA-014`, `IMP-004` to `IMP-005`, and `APP-003`.
  - Bumped [`VERSION`](../VERSION) to `1.3.27`; updated [`Changelog`](../Changelog).
- **Result**: `python -m unittest discover -s tests -v` passing (100%), PR diff strictly within `< 15,000` characters limit (`~8,500` chars).

---

### ACT-003 — Redirect ROADMAP.md to Consolidated Action Logbook (Issue `#60`)
- **Date**: `2026-10-30T22:46+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#60` (`docs/issue-60-redirect-roadmap-md`)
- **Request**: Replace obsolete root `ROADMAP.md` with an explicit redirection pointer to `docs/ACTION_LOGBOOK.md`.
- **Changes**: Replaced [`ROADMAP.md`](../ROADMAP.md) content with pointer note; bumped [`VERSION`](../VERSION) to `1.3.26`; updated [`Changelog`](../Changelog).
- **Result**: `python -m unittest discover -s tests -v` passing (100%), PR diff strictly within `< 15,000` characters limit (`~11,540` chars).

---

### ACT-002 — Merge Strategic Roadmap into Unified Action Logbook (Issue `#58`)
- **Date**: `2026-10-30T22:45+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: Issue `#58` (`docs/issue-58-merge-roadmap-into-action-logbook`)
- **Request**: Merge `ROADMAP.md` into `docs/ACTION_LOGBOOK.md` to establish a single unified source of truth for roadmap phases, milestones, and living action history.
- **Changes**:
  - Integrated Executive Phase Progress Dashboard (Phases 1-6) and Detailed Milestones into [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md).
  - Replaced [`ROADMAP.md`](../ROADMAP.md) with an explicit redirection pointer to [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md).
  - Updated [`Changelog`](../Changelog) and bumped [`VERSION`](../VERSION) to `1.3.25`.
- **Result**: `python -m unittest discover -s tests -v` passing (100%), PR diff strictly under `< 15,000` characters limit.

---

### ACT-001 — Reintegrate CIS Benchmarks Dev Rules and Governance Framework (Issue `#58` pre-work)
- **Date**: `2026-10-30T22:35+01:00`
- **Status**: `COMPLETED`
- **Issue / Branch**: `main` (commit `b7c664e`)
- **Request**: Reintegrate development and governance rules from the CIS Benchmarks Tools project (`AGENTS.md`, `.agents/AGENTS.md`, `.agents/rules/`, `03_execution_rules.md`, `04_best_practices.md`, `docs/ACTION_LOGBOOK.md`, `docs/RCA_REGISTER.md`, and `tests/test_project_governance_rules.py`).
- **Changes**: Created root [`AGENTS.md`](../AGENTS.md), workspace [`.agents/AGENTS.md`](../.agents/AGENTS.md), rule files in [`.agents/AGENTS.md`](../.agents/AGENTS.md), root `03_execution_rules.md` and `04_best_practices.md` (later consolidated into [`.agent/rules/`](../.agent/rules/03_execution_rules.md)), [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md), [`docs/RCA_REGISTER.md`](RCA_REGISTER.md), and automated test suite [`tests/test_project_governance_rules.py`](../tests/test_project_governance_rules.py).
- **Result**: 3/3 governance unit tests passed, PR diff strictly within `< 15,000` characters.
