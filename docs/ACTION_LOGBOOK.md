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
- **Changes**: Created root [`AGENTS.md`](../AGENTS.md), workspace [`.agents/AGENTS.md`](../.agents/AGENTS.md), rule files in [`.agents/rules/`](../.agents/rules/), root [`03_execution_rules.md`](../03_execution_rules.md) and [`04_best_practices.md`](../04_best_practices.md), [`docs/ACTION_LOGBOOK.md`](ACTION_LOGBOOK.md), [`docs/RCA_REGISTER.md`](RCA_REGISTER.md), and automated test suite [`tests/test_project_governance_rules.py`](../tests/test_project_governance_rules.py).
- **Result**: 3/3 governance unit tests passed, PR diff strictly within `< 15,000` characters.
