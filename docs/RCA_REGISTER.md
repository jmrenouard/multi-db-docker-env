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
- **Applied Change / Fix**: Replaced `except e:` with `except Exception as e:`, injected `MYSQL_PWD` in aliases, deferred interactive prompts to `main()`, and improved metric extraction in `scripts/aggregate_reports.sh`.
- **Result & Non-Regression Test**: All tests passed (`test_secure_password.sh`, `test_project_governance_rules.py`, `make test-config`).

---

### RCA-016 — OpenSSL Certificate Generation Fragmentation and Missing SAN Extensions
- **Date / Linked Action**: `2026-10-30` (`ACT-008` / Issue `#70`)
- **Observed Symptom**: Five distinct scripts duplicated OpenSSL certificate generation logic with inconsistent subject naming, missing Subject Alternative Name (SAN) extensions on multi-node topologies, and divergent file permissions.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Each database topology was introduced incrementally with its own customized copy of OpenSSL CLI commands.
  2. *Why?* OpenSSL options varied slightly between engines (MongoDB combined PEM, PostgreSQL postgres UID ownership, MySQL client certs).
- **Applied Change / Fix**: Consolidated PKI generator into `scripts/gen_pki.sh` with standard SAN extensions, configurable modes (`mariadb`, `standard`, `single`), combined PEM output, and strict `0600` key permissions, converting existing scripts to lightweight wrappers.
- **Result & Non-Regression Test**: `make check-ssl-all` validated all 5 topologies; `tests/test_security_ssl.sh` passed 100%.

---

### RCA-017 — Incomplete Delegation and Permission Fragmentation in Multi-DB SSL Scripts
- **Date / Linked Action**: `2026-10-30` (`ACT-009` / Issue `#72`)
- **Observed Symptom**: MongoDB, PostgreSQL PgPool-II, and Patroni SSL generator scripts retained legacy OpenSSL code with unaligned flags and skipped `--force` handling.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Migration was split atomically to remain strictly under the 15,000 PR diff character limit.
- **Applied Change / Fix**: Migrated `gen_ssl_mongo.sh` and `gen_ssl_pgpool.sh` to delegate to `gen_pki.sh` with `--force` bypass and strict permissions; added fallback in `gen_ssl_patroni.sh`.
- **Result & Non-Regression Test**: `make check-ssl-all` validated all 5 topologies; `tests/test_security_ssl.sh` passed 100%.

---

### RCA-018 — Error Shadowing and Missing "all" Support in Native PKI Engine
- **Date / Linked Action**: `2026-10-31` (`ACT-012` / Issue `#78`)
- **Observed Symptom**: Fuzzing and adversarial stress testing revealed that `mdb pki verify all` returned `unknown topology: all`, write failures in `GenerateTopologyCerts` silently returned nil error, and certificate verification failures returned `Verify failed: <nil>`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did verify all fail?* `VerifyTopologyCerts` only queried `topoMap` directly and omitted the `"all"` iteration logic present in `GenerateTopologyCerts`.
  2. *Why was the write error masked?* In `GenerateTopologyCerts`, `if err != nil || save(...) != nil { return nil, err }` evaluated `save(...) != nil` as true when `err` was still `nil`, returning `nil, nil`.
  3. *Why was verify error `<nil>`?* In `VerifyTopologyCerts`, `if err != nil || p.VerifyCertBytes(...) != nil { return false, err }` returned `false, nil` because `err` was from `os.ReadFile`.
- **Applied Change / Fix**: Added loop for `"all"` topology verification, uncoupled error evaluations into discrete statements checking and returning the specific non-nil error, and added comprehensive unit test assertions in `pkg/pki/cert_test.go`.
- **Result & Non-Regression Test**: `go test -v ./pkg/pki` passes 100%, and tampered certificates correctly fail with non-nil descriptive error diagnostics.

---

### RCA-019 — Multi-Engine Database Health Verification in Containerized Clusters
- **Date / Linked Action**: `2026-10-31` (`ACT-015` / Issue `#84`)
- **Observed Symptom**: Verifying topologies previously required separate shell scripts or heavy external Go drivers.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Engines expose distinct diagnostic commands (`wsrep_%`, replication status).
  2. *Why avoid external SDKs?* Heavy drivers bloat binary size and require live database daemons.
- **Applied Change / Fix**: Unified `Verifier` interface and pure-Go `CommandExecutor` abstraction with structured parsers.
- **Result & Non-Regression Test**: Hermetic unit tests in `pkg/dbclient/dbclient_test.go`.

---

### RCA-020 — Container Name Mismatch, Missing .env Password & Compose --env Flag in Go CLI
- **Date / Linked Action**: `2026-10-31` (`ACT-022` / Issue `#98`)
- **Observed Symptom**: `mdb test`/`report` used placeholder container names without `.env` password, and `RealCommandRunner` passed invalid `--env` flag to `docker compose`.
- **Root Cause Analysis**: Hermetic mocks did not validate live `docker-compose-*.yml` container names or `docker compose` CLI flag syntax.
- **Applied Change / Fix**: Aligned `defaultContainer`, added `resolveContainer`/`loadPassword` and `runner.NewPipeline` in `cmd/mdb/main.go`, extracted `--env` into `cmd.Env` in `pkg/docker/client.go`, and added setup scripts in `pkg/topology`.
- **Result & Non-Regression Test**: Verified via `cmd/mdb/main_test.go`, `pkg/docker/docker_test.go`, and `pkg/topology/topology_test.go` (64/64 Go tests passing).

---

### RCA-021 — Uninitialized Variables in `make client`, Unbound `$PASS` in `setup_repli.sh` & Missing Go CI Step
- **Date / Linked Action**: `2026-10-31` (`ACT-023` / Issue `#100`)
- **Observed Symptom**: `make client` failed because `DB_SERVICE`/`DB_CONTAINER` were not initialized in its subshell; `scripts/setup_repli.sh` referenced `$PASS` under `set -euo pipefail` when only `DB_PASS` was set; `Makefile` `inject-data`/`test-all` used `-p` flags; `test-config` did not invoke Go/Python unit tests in CI.
- **Root Cause Analysis**: Incremental migrations left residual CLI password flags in `Makefile` and a variable rename mismatch (`DB_PASS` vs `PASS`) in `setup_repli.sh`.
- **Applied Change / Fix**: Initialized `DB_SERVICE`/`DB_CONTAINER` in `client:`, replaced all 7 `-p` flags in `Makefile` with `-e MYSQL_PWD`, defined `PASS="$DB_PASS"` in `scripts/setup_repli.sh`, wired `test-go` and `unittest` into `Makefile` `test-config`, and pinned `haproxy:lts` across Compose files.
- **Result & Non-Regression Test**: Verified via `go test -v ./...` (64/64) and `python -m unittest discover -s tests -v` (10/10).

---

### RCA-022 — POSIX 126 `Permission denied` on `scripts/gen_pki.sh` During CI TLS Certificate Generation
- **Date / Linked Action**: `2026-11-01` (`ACT-024` / Issue `#102`)
- **Observed Symptom**: GitHub Actions run `41247154340` failed at Step #4 (`Generate and Check TLS Certificates`) with `./scripts/gen_ssl.sh: line 31: exec: .../scripts/gen_pki.sh: cannot execute: Permission denied` (`make: *** [Makefile:860: gen-ssl] Error 126`).
- **Root Cause Analysis (5 Whys)**:
  1. *Why did `make gen-ssl-all` fail?* Because `gen_ssl.sh` executed `exec "$(dirname "$0")/gen_pki.sh"` directly and Linux returned `EACCES` (POSIX 126).
  2. *Why did Linux return `EACCES`?* Because `scripts/gen_pki.sh` was stored in the Git tree with mode `100644` (non-executable) rather than `100755`.
  3. *Why did all 5 `gen_ssl*.sh` wrappers rely on the executable bit?* Because they invoked `gen_pki.sh` directly via `exec` without prefixing `bash`.
- **Applied Change / Fix**: Updated `scripts/gen_ssl.sh`, `scripts/gen_ssl_innodb.sh`, `scripts/gen_ssl_mongo.sh`, `scripts/gen_ssl_patroni.sh`, and `scripts/gen_ssl_pgpool.sh` to invoke `exec bash "$(dirname "$0")/gen_pki.sh"`, ensuring portable execution regardless of filesystem mode bits, and restored mode `100755` on `scripts/gen_pki.sh` and `scripts/aggregate_reports.sh`.
- **Result & Non-Regression Test**: Verified via `make gen-ssl-all` and `make check-ssl-all` in CI.

---

### RCA-023 — Post-Chown `rm: Permission denied` on `ssl/pgpool` Temporary Files & Host `mariadb` CLI Assumption in CI
- **Date / Linked Action**: `2026-11-01` (`ACT-025` / Issue `#104`)
- **Observed Symptom**: Run `41251104195` failed with `rm: cannot remove './ssl/pgpool/san.cnf': Permission denied` in `gen-ssl-pgpool`, and `up-galera`/`inject-employee-galera` relied on host `mariadb` and pre-initialized `test_db`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did `rm -f` fail on `./ssl/pgpool/san.cnf`?* Because `scripts/gen_pki.sh` ran `docker run ... chown -R 999:999 /ssl && chmod 755 /ssl` *before* unlinking temporary `.cnf`/`.csr`/`.srl` files, transferring directory write permissions away from the non-root runner (`uid=1001`).
  2. *Why did `up-galera` and `inject-employee-galera` risk failure on CI runners?* Because `ubuntu-latest` does not pre-install `mariadb-client` on the host or check out submodules by default.
- **Applied Change / Fix**: Moved `rm -f "$CFG" "$DIR"/*.csr "$DIR"/*.srl "$DIR"/t.csr` prior to the `CHOWN_U` block in `scripts/gen_pki.sh` and containerized `mariadb` execution in `up-galera` and `inject-employee-galera` with automatic `test_db` submodule initialization in `Makefile`.
- **Result & Non-Regression Test**: Verified via `make gen-ssl-all`, `make check-ssl-all`, and full CI workflow execution.

---

### RCA-024 — MariaDB Init Failure on Host-Mounted `0600` SSL Key (`uid=1001` vs `uid=999`) & Unbounded Wait Loop in `up-galera`
- **Date / Linked Action**: `2026-11-01` (`ACT-026` / Issue `#106`)
- **Observed Symptom**: During `make mysqltuner-galera` in CI, `galera_01` started `supervisord` (`sshd`), but `mariadbd` exited during initialization while `up-galera` waited indefinitely at `Waiting for Node 1 to start...`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did `up-galera` wait indefinitely?* Because `mariadbd` failed during initial bootstrap inside `scripts/start_mariadb.sh` and `autorestart=false` left `supervisord` running only `sshd`.
  2. *Why did temporary `mariadbd` fail during initialization?* Because `start_mariadb.sh` invoked `mariadbd --user=mysql --wsrep-on=OFF` (`uid=999`), which loaded `/etc/mysql/conf.d/ssl.cnf` (`/etc/mysql/ssl/server-key.pem`, mode `0600` owned by host `runner` `uid=1001`) and `/etc/mysql/mariadb.conf.d/999_custom.cnf` (`wsrep_provider`).
  3. *Why did final startup succeed as `root` while init failed?* Because line 96 used `exec mariadbd --user=root`, whereas lines 18 and 25 used `--user=mysql` without `--wsrep-provider=none`.
- **Applied Change / Fix**: Aligned `scripts/start_mariadb.sh` init commands to `--user=root` with `--wsrep-provider=none` and `COUNTER=$((COUNTER + 1))`, bounded `up-galera` readiness polling to 60 attempts with supervisor log output, and added fast CI fixture injection for `inject-employee-galera`.
- **Result & Non-Regression Test**: Verified via `make mysqltuner-galera` and full GitHub Actions CI pipeline.

---

### RCA-025 — Operator Precedence Bug, Subprocess Deadlock, Variable Unbound & PRNG Insecurity
- **Date / Linked Action**: `2026-11-01` (`ACT-027` / Issue `#108`)
- **Observed Symptom**: (1) `interactive_runner.py` prompt evaluated `cont != 'o' if L == 'fr' else 'y'` as `'y'` in English, ignoring `'n'`; (2) `run_command` deadlocked on >64KB stderr output; (3) `mysql_docker.py` raised `UnboundLocalError`/`IndexError` on missing/untagged containers and wiped `db10` when removing `db1`; (4) `generate_password` used MT19937 PRNG.
- **Root Cause Analysis (5 Whys)**:
  1. *Precedence & Deadlock*: `!=` binds tighter than `if...else`, evaluating to `'y'`; reading stdout to EOF before stderr saturated OS pipe buffers.
  2. *Unbound Variable & Alias Substring*: Missing container left `container` unbound before tag lookup; substring match removed overlapping alias prefixes.
- **Applied Change / Fix**: Fixed precedence to `if cont != ('o' if L == 'fr' else 'y'): return`; drained stderr concurrently via background thread; guarded container/image tags in `remove_environment` and filtered exact alias prefixes; switched to `secrets.choice`; added unit tests in `tests/test_python_runners.py`.
- **Result & Non-Regression Test**: `python -m unittest discover -s tests -v` (16/16), `test_secure_password.sh` (34/34).

---

### RCA-026 — Missing Database Driver/Credentials in Sysbench Invocation & Redundant Report Wrappers
- **Date / Linked Action**: `2026-11-02` (`ACT-028` / Issue `#110`)
- **Observed Symptom**: (1) `sysbench` commands failed when targeting password-protected or custom-port database containers due to missing `--db-driver=mysql`, `--mysql-user`, `--mysql-password`, `--mysql-host`, `--mysql-port`; (2) `pkg/report/report.go` maintained dead package-level functions (`AddStepSummary`, `WriteJSONTelemetry`, `RenderHTMLReport`) duplicating `*Report` methods.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did sysbench fail on authenticated instances?* `SysbenchRunner.Run` only passed `--threads` and `--time`, leaving driver, user, password, host, and port unset.
  2. *Why were redundant report wrappers present?* Early prototype CLI design exposed package-level helpers before the consolidated `Report` struct methods were finalized.
- **Applied Change / Fix**: Defaulted `cfg.User = "root"` in `NewSysbenchRunner`, injected `--db-driver=mysql` and connection flags in `SysbenchRunner.Run`, supplied `User: "root"` in `cmd/mdb/main.go`, removed redundant wrappers from `pkg/report/report.go`, and updated tests.
- **Result & Non-Regression Test**: Verified via `go test -v ./...` (63/63) and `python -m unittest discover -s tests -v` (16/16).

---

### RCA-027 — Hardcoded Backup Container Prefixes, CLI Password Leak & Python 3.11 Syntax Error
- **Date / Linked Action**: `2026-11-02` (`ACT-029` / Issue `#112`)
- **Observed Symptom**: Backup, restore, and failover scripts failed on root Docker Compose runs due to hardcoded container prefixes (`mariadb-`), `backup_physical.sh` exposed passwords in `ps aux`, and `interactive_runner.py:224` crashed on Python <=3.11 with `SyntaxError`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did container checks fail?* Docker Compose names containers with the directory prefix (`multi-db-docker-env-`) when run from root.
  2. *Why was password exposed on CLI?* `mariabackup` was invoked with `--password` rather than reading `MYSQL_PWD` from the environment.
  3. *Why did Python 3.11 fail?* Python <=3.11 disallows backslashes inside f-string `{...}` expressions.
- **Applied Change / Fix**: Dynamically resolved container names with fallback in `scripts/backup_logical.sh`, `scripts/backup_physical.sh`, `scripts/restore_logical.sh`, `scripts/restore_physical.sh`, `tests/test_failover.sh`, and `tests/test_backup_restore.sh`; passed `-e MYSQL_PWD` to `docker exec` in `backup_physical.sh`; removed escaped quote in `interactive_runner.py:224`.
- **Result & Non-Regression Test**: All tests passed: `python -m unittest discover -s tests -v` (16/16), `go test -v ./...` (63/63), `bash tests/test_secure_password.sh` (34/34), `bash tests/test_backup_restore.sh` (8/8), `bash tests/test_failover.sh`.

---

### RCA-028 — Hardcoded Perf/HAProxy Node Names & Fragile xargs .env Parsing
- **Date / Linked Action**: `2026-11-02` (`ACT-030` / Issue `#114`)
- **Observed Symptom**: `test_perf_galera.sh`, `test_perf_repli.sh`, and `test_haproxy_galera.sh` failed on root Compose deployments due to hardcoded container names (`mariadb-galera_0*-1`, `mariadb-mariadb_0*-1`); 7 remaining scripts used `export $(grep -v '^#' .env | xargs)` which broke on spaces, inline quotes, and empty/comment-only lines.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did node lookups fail?* Compose names containers `multi-db-docker-env-*` from repository root.
  2. *Why did xargs break?* `xargs` splits arguments on whitespace and mishandles quoted strings or comments.
- **Applied Change / Fix**: Dynamically resolved node names with fallback in `test_perf_galera.sh`, `test_perf_repli.sh`, and `test_haproxy_galera.sh`; replaced `xargs` with `if [ -f .env ]; then set -a; . ./.env; set +a; fi` across `gen_profiles.sh`, `setup_repli.sh`, `patroni/generate_certs.sh`, `test_innodb_cluster.sh`, `test_lb_galera.sh`, `test_patroni.sh`, and `test_pgpool.sh`.
- **Result & Non-Regression Test**: All tests pass: `python -m unittest discover -s tests -v` (16/16), `go test -v ./...` (63/63), `bash tests/test_env.sh`, `bash tests/test_config.sh`, `bash tests/test_security_ssl.sh`, `bash tests/test_profiles.sh`.

---

### RCA-029 (RCA-012) — Unauthenticated MariaDB Conflict Call, Missing Mongo Perf TLS Fallback & Config Subshell Loss
- **Date / Linked Action**: `2026-11-02` (`ACT-032` / Issue `#118`)
- **Observed Symptom**: (1) `test_galera.sh:222` omitted credentials/SSL flags, failing with silent `Access denied`; (2) `test_perf_mongo.sh:59` failed on TLS-enabled Mongo; (3) `test_config.sh:105` subshell loop lost `add_result` calls and omitted `RET=1`; (4) `docker-compose-galera.yml:27` mapped SSH to 22001 instead of 24001, and unquoted passwords broke profile aliases.
- **Root Cause Analysis (5 Whys)**:
  1. *Galera conflict failure*: Background `mariadb` lacked credentials, exiting immediately rather than holding an open transaction.
  2. *Mongo perf failure*: `run_mongo_js` lacked the 3-tier fallback chain (cert keyfile -> TLS -> plaintext).
  3. *Config report omission*: Pipeline `awk | while` ran in a subshell, losing results and `RET=1`.
  4. *SSH port mismatch*: Node 1 used 22001 while Nodes 2/3 used 24002/24003.
- **Applied Change / Fix**: Authenticated line 222 in `test_galera.sh` and added `wait $PID1 || true`; added 3-tier TLS fallback to `run_mongo_js` in `test_perf_mongo.sh`; used process substitution and set `RET=1` in `test_config.sh`; validated all 8 compose files; synchronized port 24001 and quoted `MYSQL_PWD` in `gen_profiles.sh` and `docker-compose-galera.yml`; simplified `.env` parsing in `test_galera.sh` and `test_repli.sh`.
- **Result & Non-Regression Test**: `tests/test_config.sh` passed (41 checks); `tests/test_profiles.sh` passed; `tests/test_secure_password.sh` passed (34/34); `python -m unittest discover -s tests -v` (16/16); `go test -v ./...` (63/63).

---

### RCA-030 — Missing Strict Error Handling in Scripts & Profiles Heredoc Quoting Bug
- **Date / Linked Action**: `2026-11-02` (`ACT-033` / Issue `#120`)
- **Observed Symptom**: Shell scripts lacked `set -euo pipefail`; `gen_profiles.sh` heredoc wrote literal backslashes into profile aliases (`\"rootpass\"`), breaking MariaDB client authentication.
- **Root Cause Analysis (5 Whys)**: Unquoted heredoc `\"` retains literal backslashes in POSIX bash; scripts lacked strict flags permitting silent error propagation.
- **Applied Change / Fix**: Replaced `\"` with `"` in `gen_profiles.sh`; added `set -euo pipefail` across 9 shell scripts; added Patroni defaults and sshd guards.
- **Result & Non-Regression Test**: `test_profiles.sh`, `test_secure_password.sh` (34/34), `test_config.sh`, `unittest` (16/16), and `go test` (63/63) pass cleanly.

---

### RCA-031 — Latent Script Crashes under `set -euo pipefail` (Arithmetic, Pipestatus, and Unbound Arrays)
- **Date / Linked Action**: `2026-11-02` (`ACT-035` / Issue `#124`)
- **Observed Symptom**: Adding `set -euo pipefail` to bash scripts without thorough guards introduced latent runtime exits: (1) `tests/test_galera.sh:80` `((MATCH_COUNT++))` returned exit status 1 when `MATCH_COUNT=0`, aborting cluster readiness checks; (2) `tests/test_galera.sh:250` expected duplicate key insert error 1062 to be captured in `ERR_MSG=$(...)`, but non-zero status crashed the script before error validation; (3) `tests/test_galera.sh:290` provider options grep exited with 1 on missing keys, failing the pipeline under `pipefail`; (4) `tests/test_repli.sh:82-83` `grep "Slave_IO_Running:"` failed if replication hadn't initialized yet, killing the wait loop; (5) `tests/test_lb_galera.sh:87` `${#hosts_count[@]}` crashed with `unbound variable` under `set -u` when 0 requests succeeded because `declare -A hosts_count` was uninitialized.
- **Root Cause Analysis (5 Whys)**:
  1. *Arithmetic*: In Bash `((expr))`, if expression evaluates to 0, return status is 1. Under `set -e`, this triggers an immediate script exit.
  2. *Command substitution*: Command substitutions `$(...)` inherit `set -e`; intentional failures must append `|| true`.
  3. *Pipefail*: Under `pipefail`, any non-zero exit in a pipeline causes the entire pipeline to exit non-zero; optional grep matches must be guarded.
  4. *Unbound array*: In Bash 5 under `set -u`, querying the length of an associative array declared with bare `declare -A arr` before adding keys raises an unbound variable error.
- **Applied Change / Fix**: Replaced `((var++))` with `var=$((var + 1))`; appended `|| true` to command substitutions and pipeline greps; initialized associative arrays as `declare -A arr=()`; added `|| true` to `get_latency()` ping.
- **Result & Non-Regression Test**: All tests pass cleanly without latent traps under `set -euo pipefail`; verified via `bash tests/test_config.sh`, `bash tests/test_profiles.sh`, and `go test -v ./...`.

---

### RCA-032 — Operator Precedence in Provider Options Subshell & Incomplete French Localization Scan
- **Date / Linked Action**: `2026-11-02` (`ACT-039` / Issue `#132`)
- **Observed Symptom**: (1) In `tests/test_galera.sh:290`, `current=$(echo "$PROVIDER_OPTS" | grep -oP "$key = \K[^;]+" || true | xargs)` left trailing whitespace untrimmed when `$key` matched; (2) Residual French comments, UI strings, and HTML labels persisted in `scripts/patroni/entrypoint_etcd.sh`, `scripts/patroni/generate_certs.sh`, `tests/test_galera.sh`, `tests/test_perf_galera.sh`, `tests/test_perf_repli.sh`, and `tests/test_haproxy_galera.sh` because `test_no_french_table_headers_remain` only checked 3 hardcoded table header strings.
- **Root Cause Analysis (5 Whys)**:
  1. *Operator Precedence*: In Bash, pipe `|` binds tighter than logical OR `||`. The syntax `grep ... || true | xargs` is parsed as `(grep ...) || (true | xargs)`. When `grep` succeeded, `||` short-circuited and skipped `xargs` completely, leaving extracted values untrimmed.
  2. *Incomplete Governance Scan*: Early localization PRs checked and translated Markdown table headers and log messages, but missed internal bash comments, HTML UI cards, and search placeholders. The unit test `test_no_french_table_headers_remain` was overly specific and did not scan for French accents or common French terms.
- **Applied Change / Fix**: Moved `| xargs` before `|| true` in `tests/test_galera.sh:290` (`grep ... | xargs || true`); translated all 26 residual French lines across the 6 affected scripts into English; expanded `test_no_french_table_headers_remain` with regex covering accented characters and French tokens.
- **Result & Non-Regression Test**: All tests pass cleanly: `tests/test_project_governance_rules.py` (6/6), `bash tests/test_config.sh`, `bash tests/test_secure_password.sh` (34/34), `bash tests/test_profiles.sh`, and `go test -v ./...` (63/63).

### RCA-042 — MongoVerifier TLS Fallback & PKIEngine Container SANs
- **Date / Linked Action**: `2026-11-02` (`ACT-045` / Issue `#140`)
- **Observed Symptom**: `mdb test mongo` failed on TLS ReplicaSets; `mdb pki` rejected `mongo8`; Compose container names (`mysql_node1-3`, `mongo_n1-3`, `pg_node1-3`, `galera_01-03`) were missing from SANs.
- **Root Cause Analysis**: `MongoVerifier.execEval` lacked TLS flags; `topoMap`/`allTopos` lacked `mongo8`; PKIEngine SANs only had user aliases.
- **Applied Change / Fix**: Added 4-tier TLS fallback in `MongoVerifier.execEval`; added `mongo8` and container SANs in `pkg/pki/cert.go` and `scripts/gen_ssl*.sh`; added tests in `dbclient_test.go` and `cert_test.go`.
- **Result & Non-Regression Test**: `go test` (76/76 pass), `unittest` (18/18), `test_config.sh` pass.

---

### RCA-043 — Sysbench Executor Missing MYSQL_PWD Environment, CLI Version Drift & French Default Password
- **Date / Linked Action**: `2026-11-02` (`ACT-046` / Issue `#142`)
- **Observed Symptom**: (1) `SysbenchRunner.Run` passed `nil` for `env` to `Executor.Exec`, preventing container environments from receiving `MYSQL_PWD`; (2) `cmd/mdb/main.go` hardcoded `var version = "2.0.2"`, drifting from project `VERSION` (`2.0.19`); (3) `pkg/config/config.go` defaulted `RootPassword` to French `"votre_mot_de_passe_super_secret"`, violating project English and standard `"rootpass"` credentials.
- **Root Cause Analysis (5 Whys)**:
  1. *Why did Sysbench lack MYSQL_PWD in env?* Early implementation passed credentials solely via CLI arguments (`--mysql-password`) without populating container process environment slice.
  2. *Why did mdb version drift?* `cmd/mdb/main.go` initialized a static string constant from early v2.0 development without reading dynamic repository release tags or `VERSION` file.
  3. *Why was French default password present?* Legacy prototype configuration originated from initial French proof-of-concept before English-only standardization.
- **Applied Change / Fix**: Injected `MYSQL_PWD` in the `env` slice when `r.cfg.Password != ""` in `pkg/bench/sysbench.go:102`; implemented `resolveVersion()` in `cmd/mdb/main.go` reading and trimming `VERSION` from disk with fallback to `version = "2.0.20"`; updated `pkg/config/config.go` default to `"rootpass"`; expanded test suites in `pkg/bench/sysbench_test.go`, `cmd/mdb/main_test.go`, and `pkg/config/config_test.go`.
- **Result & Non-Regression Test**: Verified via `go test -v ./...` (66/66 pass across 9 packages), `python -m unittest discover -s tests -v` (18/18), `bash tests/test_config.sh`, and `bash tests/test_secure_password.sh` (34/34).

---

### RCA-044 — Hardcoded Replication Credentials in Cluster Scripts & Omission of Conf Scripts from Governance Audits
- **Date / Linked Action**: `2026-11-02` (`ACT-047` / Issue `#144`)
- **Observed Symptom**: `conf/innodb-cluster/setup_cluster.sh` and `scripts/pgpool/setup_replication.sh` hardcoded replication credentials (`'replpass'`, `'replipass'`), preventing custom `.env` overrides; `tests/test_config.sh` did not validate `conf/**/*.sh` scripts; `tests/test_project_governance_rules.py` only scanned `scripts/` and `tests/` for `set -euo pipefail` and did not verify absence of residual French strings in Go packages (`votre_mot_de_passe_super_secret`).
- **Root Cause Analysis (5 Whys)**:
  1. *Why were replication passwords hardcoded?* Initial setup scripts were created as standalone bootstrapping PoCs without sourcing `.env` or parameterizing replication variables.
  2. *Why were `conf/**/*.sh` scripts omitted from configuration validation?* `tests/test_config.sh` only listed files under `scripts/` in `SCRIPTS_TO_CHECK`.
  3. *Why did governance tests not scan `conf/`?* `test_all_bash_scripts_have_set_euo_pipefail` targeted `scripts/` and `tests/`, assuming `conf/` only contained static `.cnf` and `.sql` configuration files.
  4. *Why did Go packages lack a French string governance test?* `test_no_french_table_headers_remain` only inspected shell scripts.
- **Applied Change / Fix**: Sourced `.env` at startup and parameterized `REPL_USER` and `REPL_PASS` with default fallbacks in `conf/innodb-cluster/setup_cluster.sh` and `scripts/pgpool/setup_replication.sh`; added `conf/innodb-cluster/setup_cluster.sh`, `conf/mongo-rs/setup_rs.sh`, and `conf/mongo-rs/setup_rs_mongo8.sh` to `tests/test_config.sh` with `set -euo pipefail` verification; extended `test_all_bash_scripts_have_set_euo_pipefail` in `tests/test_project_governance_rules.py` to scan `conf/**/*.sh`; added `test_no_french_strings_in_go_packages` asserting absence of `votre_mot_de_passe_super_secret` across `pkg/` and `cmd/`.
- **Result & Non-Regression Test**: Verified via `go test -v ./...` (66/66), `python -m unittest discover -s tests -v` (19/19, 6 skipped), `bash tests/test_config.sh`, and `bash tests/test_secure_password.sh` (34/34).

---

### RCA-045 — Cluster Guides Test Drift, CLI Credentials, Mongo 8 PKI & Docker Fallback
- **Date / Linked Action**: `2026-11-02` (`ACT-048` / Issue `#146`)
- **Observed Symptom**: (1) Cluster guides lagged behind 14/18/12 test groups; (2) `mdb pki` lacked `ssl/certs/mongo8`; (3) `mysql_docker.py` lacked `ImportError` guard; (4) `Makefile` omitted `export DB_ROOT_PASSWORD`.
- **Root Cause Analysis (5 Whys)**: Guides drifted from test suites; Mongo 8 PKI target lacked generator coverage; top-level python imports failed without docker.
- **Applied Change / Fix**: Synchronized InnoDB, PgPool, and Mongo guides; updated `gen_ssl_mongo.sh`; added `ImportError` fallback in `mysql_docker.py`; exported `DB_ROOT_PASSWORD` in `Makefile`.
- **Result & Non-Regression Test**: Verified via `go test -v ./...` (66/66), `unittest` (19/19), `test_config.sh`, `test_secure_password.sh` (34/34), and `mdb pki verify all`.

---

### RCA-046 — Residual French Patroni Echoes, Go Binary Version Drift & Missing Ldflags Injection
- **Date / Linked Action**: `2026-11-02` (`ACT-049` / Issue `#148`)
- **Observed Symptom**: (1) `Makefile:21,25,29,33` contained French echo messages in Patroni cluster targets; (2) `Makefile` `build-go` target lacked `-X main.version=...` link flag; (3) `cmd/mdb/main.go` `var version` was frozen at `"2.0.20"` instead of tracking the `VERSION` file; (4) `test_no_french_table_headers_remain` did not scan `Makefile` or `conf/`.
- **Root Cause Analysis (5 Whys)**:
  1. *Why were French echoes present in Patroni targets?* When Patroni cluster targets were introduced, UI echo messages were written in French without automated governance linting.
  2. *Why did governance tests miss them?* `test_no_french_table_headers_remain` only checked `scripts/` and `tests/` shell scripts.
  3. *Why was cmd/mdb version out of sync?* Release automation bumped root `VERSION` without updating package-level `var version` in `cmd/mdb/main.go`, and `go build` was invoked without compile-time ldflags.
- **Applied Change / Fix**: Localized Patroni echo strings to English in `Makefile`; updated `build-go` recipe to inject `-X main.version=$$(tr -d '[:space:]' < VERSION)`; synchronized `var version = "2.0.23"` in `cmd/mdb/main.go`; extended `test_no_french_table_headers_remain` to scan `Makefile` and `conf/`; added `test_version_synchronization_and_ldflags_injection` in `tests/test_project_governance_rules.py`.
- **Result & Non-Regression Test**: Verified via `python -m unittest tests/test_project_governance_rules.py -v` (8/8 pass), `go test -v ./...` (66/66 pass), and `make build-go` verifying `./bin/mdb version` prints `mdb version 2.0.23`.

---

### RCA-047 — Mongo 8 TLS Parity & Script Resilience
- **Date / Linked Action**: `2026-11-02` (`ACT-050` / `#150`)
- **Observed Symptom**: Mongo 8 compose/setup lacked TLS; mongo8-up lacked gen-ssl-mongo; NewMongo8Topology lacked certs.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Mongo 8 added without TLS parity.
  2. *Why?* Plain mongosh fails on requireTLS.
- **Applied Change / Fix**: Added TLS in compose/setup/Makefile/Go topology, tests.
- **Result & Non-Regression Test**: `unittest`, `go test`, `test_config.sh` pass.

---

### RCA-048 — Patroni & PostgreSQL Docs Drift against Topologies and Tests
- **Date / Linked Action**: `2026-11-02` (`ACT-051` / Issue `#152`)
- **Observed Symptom**: Patroni docs lacked ports (6432, 8008, 2379), PGPASSWORD auth, mdb CLI commands, and 8 test groups; postgresql_support.md had outdated test counts (4 vs 11) and missing pooling/TLS; README.md referenced 63+ tests and 2.0.2.
- **Root Cause Analysis (5 Whys)**:
  1. *Why?* Early documentation was authored prior to PgBouncer, REST API, test enrichment, and v2.0 Go CLI.
  2. *Why?* Lacked automated documentation-to-compose port verification.
- **Applied Change / Fix**: Synchronized patroni_cluster.md, postgresql_support.md, README.md, Makefile, VERSION, cmd/mdb.
- **Result & Non-Regression Test**: `unittest` (21/21), `go test` (67/67), `test_config.sh` pass.

---

### RCA-049 — pgEdge Spock 5 `spock_output` `SQLSTATE 42501`, Localhost Binding & `pg_hba.conf` Rejection
- **Date / Linked Action**: `2026-11-19` (`ACT-055` / `#164`, `#166`)
- **Observed Symptom**: `ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal` rejected logical slot creation (`SQLSTATE 42501`) on `spock_output`, bound only to `localhost`, and lacked replication HBA rules.
- **Root Cause Analysis**: Rocky UBI image defaults to `output_plugin_libraries='pgoutput, test_decoding'`, `listen_addresses=localhost`, and `logging_collector=on`.
- **Applied Change / Fix**: Overrode postgres flags (`listen_addresses=*`, `logging_collector=off`, `output_plugin_libraries=pgoutput,spock_output`) in `docker-compose-pgedge.yml` and appended `host replication all all scram-sha-256` in `scripts/pgedge/setup_pgedge.sh`.
- **Result & Non-Regression Test**: `tests/test_pgedge.sh` passed (`11` PASS, `0` FAIL, `6` EXPECTED_LIMITATION) with 3-node full mesh active.

### RCA-050 — Bucardo `db_getconn` `PL/PerlU` Failure on Stock `postgres:17` Image
- **Date / Linked Action**: `2026-11-19` (`ACT-056` / `#168`, `#170`)
- **Observed Symptom**: `bucardo install` failed against stock `postgres:17` because `bucardo.schema` creates `db_getconn()` in `plperlu` using Perl `DBI` / `DBD::Pg`.
- **Applied Change / Fix**: Added `scripts/bucardo/Dockerfile.pg` installing `postgresql-plperl-17`, `libdbi-perl`, and `libdbd-pg-perl` on the database containers alongside `scripts/bucardo/Dockerfile` (`bucardo` 5.6.0-4).
- **Result & Non-Regression Test**: `tests/test_bucardo.sh` passed (`7` PASS, `0` FAIL, `7` EXPECTED_LIMITATION) with `plperlu=1` and `sync_mm` active.

### RCA-051 — Keyless `pgbench_history` `SQLSTATE 55000` / Silent Skip Across Logical & Trigger Replication
- **Date / Linked Action**: `2026-11-19` (`ACT-054..059` / `#162`, `#166`, `#170`, `#184`)
- **Observed Symptom**: `pg-birep` raised `SQLSTATE 55000` on `UPDATE`/`DELETE` of keyless `pgbench_history_nokey`; `pgedge` assigned keyless tables to `default_insert_only` (skipping `UPDATE` silently); `bucardo` `validate_sync` rejected tables without a PK; `citus` blocked post-distribution `ADD PRIMARY KEY` / `SERIAL` with `0A000`.
- **Applied Change / Fix**: Added explicit surrogate PK `hid` (`INCREMENT BY 2` on `pg-birep`/`bucardo`, `snowflake.nextval()` on `pgedge`, `PRIMARY KEY(aid, hid)` on `citus`, `unique_rowid()` on `cockroach`) in `scripts/bench_pg_lib.py` and verified surrogate PK fixes in `tests/test_*.sh`.
- **Result & Non-Regression Test**: Cross-node `UPDATE` convergence passed across all engines.

### RCA-052 — Citus `SQLSTATE 0A000` on Non-Distribution-Key `UNIQUE` Indexes & Missing `pgvector`
- **Date / Linked Action**: `2026-11-19` (`ACT-057` / `#172`, `#174`)
- **Observed Symptom**: Creating `UNIQUE(email)` on distributed `citus_accounts` or `CREATE EXTENSION vector` on `citusdata/citus:14.2.0-pg17` failed with `SQLSTATE 0A000`.
- **Applied Change / Fix**: Documented composite `UNIQUE(tenant_id, email)` requirement in `tests/test_citus.sh` and `documentation/pg_multimaster.md`, and recorded `vector=ERR(0A000)` cleanly.
- **Result & Non-Regression Test**: `tests/test_citus.sh` verified both the `0A000` boundary and composite unique key convergence.

### RCA-053 — Distributed Raft `40001` Serialization Retries, `2/3` Quorum Halt (`57014`), and `TestResolveVersion` File Lock
- **Date / Linked Action**: `2026-11-19` (`ACT-058`, `ACT-060` / `#178`, `#182`, `#190`)
- **Observed Symptom**: (1) Concurrent updates hit `SQLSTATE 40001` (`WriteTooOldError`) on CockroachDB/YugabyteDB; CockroachDB raised `XCEXF` on `TEMP TABLE` and `42601` on `LISTEN`; YugabyteDB raised `0A000` on `LISTEN/NOTIFY`; `2/3` node loss halted both clusters (`cockroach` `57014`, `yugabyte` timeout). (2) `TestResolveVersion` once left a transient `cmd/mdb/VERSION` file under sync-client lock on `/mnt/c`.
- **Applied Change / Fix**: Proved `40001` retry convergence and `1/3` vs `2/3` quorum boundaries in `tests/test_{cockroach,yugabyte}.sh`; documented `685` ignored errors in non-retrying `sysbench` on CockroachDB; removed transient `cmd/mdb/VERSION` and re-verified `go test -v ./cmd/mdb`.
- **Result & Non-Regression Test**: `go test ./...` passes 100%; `tests/test_cockroach.sh` and `tests/test_yugabyte.sh` passed 100%.

### RCA-054 -- `pg-logical` Sequence Non-Synchronization Trap (`SQLSTATE 23505` Post-Failover)
- **Date / Linked Action**: `2026-11-19` (`ACT-063`, `ACT-064` / `#204`, `#206`)
- **Observed Symptom**: After replicating 50 rows into `seq_trap` / `ext_t18` from `pg_logical_pub` (`last_value=50|true`), `pg_logical_sub` sequence state remained stuck at `1|false`, causing the first post-failover `INSERT` on the subscriber to fail with `SQLSTATE 23505`.
- **Root Cause Analysis**: Native PostgreSQL 17 logical replication (`pgoutput`) streams table row changes but does not synchronize sequence state (`nextval` / `setval`), unlike physical WAL streaming (`pg-streaming`), which preserved `last_value=66|true` across `pg_promote()` with zero `23505`.
- **Applied Change / Fix**: Verified both the `23505` trap and manual `SELECT setval('seq_trap_id_seq', (SELECT max(id) FROM seq_trap))` remediation (`next id=51`) in `tests/test_pg_logical.sh` and `scripts/test_pg_extended_matrix.sh` (`T18`).
- **Result & Non-Regression Test**: Reproducibly verified in `tests/test_pg_logical.sh` and across all 10 topologies in `T18`.

### RCA-055 -- `pgedge` Minimal Image `SQL_ASCII` Server Encoding Failure (`SQLSTATE 54000`)
- **Date / Linked Action**: `2026-11-19` (`ACT-064` / `#208`)
- **Observed Symptom**: `T14` rich-data fidelity probe calling `chr(233)||chr(20013)||chr(128640)` failed on `pgedge` with `SQLSTATE 54000` (`requested character too large for encoding`).
- **Root Cause Analysis**: `ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal` initializes `labdb` with `SQL_ASCII` encoding rather than `UTF8`, rejecting multi-byte `chr()` codepoints above 127.
- **Applied Change / Fix**: Added defensive `SQL_ASCII` fallback in `scripts/test_pg_extended_lib.py` (`run_t14_fidelity`) capturing `SQL_ASCII chr()=54000` and inserting escaped UTF-8 bytes via `encode(decode('c3a9e4b8adf09f9a80','hex'),'escape')`.
- **Result & Non-Regression Test**: Verified 3/3 identical MD5 (`f798eb5a`, `65536B BYTEA`) across all 3 pgEdge nodes while recording `54000` in `verified_sqlstates`.

### RCA-056 -- `pg-birep` & `pg-logical` `FOR ALL TABLES` Sysbench Schema Propagation & Refresh
- **Date / Linked Action**: `2026-11-19` (`ACT-064` / `#212`)
- **Observed Symptom**: Running `sysbench prepare` (`sbtest1`..`sbtest4`) on node 1 against `FOR ALL TABLES` logical publications did not create target tables on peer nodes, breaking logical replication apply during `E2`-`E4` sysbench runs.
- **Root Cause Analysis**: Native PostgreSQL logical replication does not auto-propagate DDL (`CREATE TABLE`) and requires explicit `ALTER SUBSCRIPTION ... REFRESH PUBLICATION` once schemas exist on subscribers.
- **Applied Change / Fix**: Implemented `pg_dump -s -t 'sbtest*' | psql` peer schema propagation, `ALTER SUBSCRIPTION ... REFRESH PUBLICATION WITH (copy_data=true)`, `srsubstate='r'` readiness polling, and post-suite `_drop_sb_sub()` cleanup in `scripts/bench_pg_v2_lib.py`.
- **Result & Non-Regression Test**: `E2_sysbench_oltp_ro`, `E3_sysbench_oltp_wo`, and `E4_sysbench_point_select` passed cleanly on `pg17-logical` (`146,564.77 TPS` point-select) and `pg-birep` (`141,203.99 TPS`).

### RCA-057 -- Bucardo 5 `T13` Cross-Node FK Race (`SQLSTATE 23503`) & `T16` Metadata-Node `SIGKILL` Loss
- **Date / Linked Action**: `2026-11-19` (`ACT-064` / `#206`, `#208`)
- **Observed Symptom**: (1) Immediate cross-node child inserts in `T13` failed `0/10` (`23503x10`) on `bucardo`; (2) `SIGKILL` on `bucardo_node1` in `T16` permitted peer write `id=21` on `bucardo_node2`, yet post-restart state remained `20/21` (outage peer row not synchronized back).
- **Root Cause Analysis**: (1) Trigger/daemon async polling introduces `p50=548.74 ms` (`p95=1,275.25 ms`) visibility lag (`T15`), causing cross-node child inserts to precede parent arrival; (2) `bucardo_node1` hosts the `bucardo` metadata database itself, making it a single point of failure for sync coordination under hard `SIGKILL` crashes.
- **Applied Change / Fix**: Documented both operational limits in `scripts/test_pg_extended_lib.py`, `scripts/test_pg_extended_matrix.sh`, and `documentation/pg_multimaster{,_fr}.md`.
- **Result & Non-Regression Test**: Reproducibly verified `23503;23505`, `p50=548.74 ms`, and `post_restart=20/21` in `extended_functional_matrix.csv`.

### RCA-058 -- Go PKI Expiry Bypass, Missing `NewVerifier` Topologies & Sysbench CLI Password Exposure
- **Date / Linked Action**: `2026-11-20` (`ACT-071` / `#225`, PR `#234`)
- **Observed Symptom**: (1) `VerifyCertBytes` passed expired certificates; (2) `mdb test`/`mdb report` rejected `standalone` and all 8 PostgreSQL v2.1–v2.2 topologies; (3) `pkg/dbclient/mysql.go` lacked `Seconds_Behind_Source` fallback; (4) `pkg/bench/sysbench.go` passed `--mysql-password=` on CLI and swallowed errors.
- **Root Cause Analysis**: `VerifyCertBytes` pinned `CurrentTime: cert.NotBefore.Add(time.Minute)` instead of `time.Now()`; `NewVerifier` switch lagged behind `DefaultRegistry()`; MySQL 8.4+ renamed slave status fields; sysbench command builder leaked credentials via argv.
- **Applied Change / Fix**: Removed `CurrentTime` override (`pkg/pki/cert.go`), added `standalone` + 8 Postgres topologies to `NewVerifier` (`pkg/dbclient/dbclient.go`), added `Seconds_Behind_Source` fallback (`pkg/dbclient/mysql.go`), and removed `--mysql-password=` CLI arg & error masking (`pkg/bench/sysbench.go`).
- **Result & Non-Regression Test**: `go test -v ./...` passes 9/9 packages including 4 dedicated regression tests.

### RCA-059 -- Python `bench_pg_lib.py` Positional `chk=False` Password Bug & Runner Hardening
- **Date / Linked Action**: `2026-11-20` (`ACT-071` / `#237`, PR `#241`)
- **Observed Symptom**: (1) Seven `bc([...], False)` calls in `scripts/bench_pg_lib.py` passed `PGPASSWORD=False` with `chk=True`, crashing instead of retrying/logging unsupported topologies; (2) `interactive_runner.py` misrouted `PostgreSQL`, omitted `RUNNING` output, and lacked HTML escaping; (3) `mysql_docker.py` printed passwords to stdout, left `mysql.bashrc` world-readable, and deleted shared images on `rm`.
- **Root Cause Analysis**: Positional argument mismatch in `bc(a, pw="", chk=True)`; missing target mapping and HTML sanitization in `interactive_runner.py`; missing `chmod 600` and overly aggressive image cleanup in `mysql_docker.py`.
- **Applied Change / Fix**: Switched all 7 calls to `chk=False`, mapped `PostgreSQL`->`postgres` with `html.escape`, enforced `chmod 600` on `mysql.bashrc`, suppressed stdout password, fixed `--status stopped` / `Ports or {}`, and preserved shared images on `rm`.
- **Result & Non-Regression Test**: `tests/test_python_audit_fixes.py` + `tests/test_python_runners.py` pass 100%.

### RCA-060 -- Shell Backup `pipefail` Masking, Broken Makefile Syntax & Unchecked Exit Codes
- **Date / Linked Action**: `2026-11-20` (`ACT-071` / `#227`, PR `#240`)
- **Observed Symptom**: (1) `mariadb-dump | pigz` and `unpigz | mariadb` inside `bash -c` returned 0 on dump/decompress failure; (2) `Makefile` `check-galera`/`check-repli` executed `$$( (NODE:-1) )`; (3) `mongo-status`/`mongo8-status` failed against `--tlsMode requireTLS`; (4) `test-all` used `employees` on `mysql96`; (5) `check-ssl-all` and `run_mysqltuner.sh` masked failures; (6) `make logs` ignored `service=`.
- **Root Cause Analysis**: Missing `set -o pipefail` and unquoted interpolation inside inner `bash -c`; typo in Make variable expansion; missing `--tls` flags on `mongosh`; swallowed non-zero statuses.
- **Applied Change / Fix**: Added `set -o pipefail` + positional args in `backup_logical.sh`/`restore_logical.sh`, fixed `$${NODE:-1}`, added TLS flags to Mongo status targets, set `PRIMARY_DB=sakila` for `mysql96`, propagated non-zero exits in `check-ssl-all`/`run_mysqltuner.sh`, and honored `$(service)` in `make logs`.
- **Result & Non-Regression Test**: `bash -n` (all tracked `.sh`) and `make -n` dry-runs pass 100%.

### RCA-061 -- Baked SSH Host Keys, `privileged: true` Containers & Duplicate Scripts/Files
- **Date / Linked Action**: `2026-11-20` (`ACT-071` / `#242`, PR `#243`)
- **Observed Symptom**: `Dockerfile` baked static SSH host keys into image layers; Galera/Replication compose files requested `privileged: true`; `gen_profiles.sh` and `haproxy.pem` lacked `chmod 600`; `setup_rs_mongo8.sh` duplicated `setup_rs.sh`; unused `conf/mongo-rs/keyfile`, `.code-workspace.bak`, and invalid `requirements.txt` polluted the repo; `mysql57` was missing from Traefik profiles.
- **Root Cause Analysis**: Legacy prototype shortcuts carried forward without periodic lean/security audit.
- **Applied Change / Fix**: Moved `ssh-keygen -A` to runtime (`scripts/start_mariadb.sh`), dropped `privileged: true`, enforced `chmod 600`, parameterized `conf/mongo-rs/setup_rs.sh` (`MONGO_NODES`), deleted dead/duplicate files, renamed `requirements.txt` -> `PREREQUISITES.txt`, and added `mysql57` to Traefik profiles (`-107` net lines).
- **Result & Non-Regression Test**: `python -m unittest discover -s tests -v` (46 tests) and `go test ./...` (9/9) pass.

### RCA-062 -- CI `ModuleNotFoundError: yaml` in Static Compose Validation
- **Date / Linked Action**: `2026-11-20` (`ACT-070` / `#228`, PR `#233`)
- **Observed Symptom**: `tests/test_repo_static.py` failed on bare `ubuntu-latest` CI runners without `PyYAML` installed.
- **Root Cause Analysis**: Unconditional `import yaml` assumed `PyYAML` was preinstalled in the CI Python environment.
- **Applied Change / Fix**: Guarded `import yaml` with `try/except ImportError` and added a stdlib regex fallback verifying `services:` and `image:`/`build:` keys when `PyYAML` is absent.
- **Result & Non-Regression Test**: `test_repo_static.py` passes both with `PyYAML` and with `sys.modules['yaml'] = None`.

### RCA-063 -- CI MySQLTuner `v2.6.0` Division by Zero on MariaDB 11.8 Galera (`exit 255`) & Hidden Failure Output
- **Date / Linked Action**: `2026-11-20` (`ACT-073` / Issue `#250`)
- **Observed Symptom**: After PR `#240` removed `|| true` in `scripts/run_mysqltuner.sh`, GitHub Actions `test-and-validate` (run `44750937954`) failed in `make mysqltuner-galera` with `exit code: 255` on all 3 Galera nodes, with no error text printed in CI logs.
- **Root Cause Analysis**: `.github/workflows/ci.yml` pinned `MySQLTuner v2.6.0`, which divides by `innodb_buffer_pool_chunk_size` at line 6547 (`main::mysql_innodb()`). MariaDB >= 10.8 (including Galera MariaDB 11.8.9) defaults `innodb_buffer_pool_chunk_size` to `0` (`autosize`), raising `Illegal division by zero` (`exit 255`). Redirecting stdout/stderr solely to `$OUTPUT_FILE` hid the exception from CI logs.
- **Applied Change / Fix**: Upgraded the pinned MySQLTuner version in `.github/workflows/ci.yml` from `v2.6.0` to `v2.9.4` (which explicitly skips chunk-size division when `innodb_buffer_pool_chunk_size == 0`) and printed the last 30 lines of `$OUTPUT_FILE` to stderr on failure in `scripts/run_mysqltuner.sh`.
- **Result & Non-Regression Test**: `bash -n scripts/run_mysqltuner.sh`, `python -m unittest discover -s tests -v`, and GitHub Actions `test-and-validate` E2E `make mysqltuner-galera` pass green.

### RCA-064 -- PostgreSQL 18 Official Docker Image `PGDATA` Path & Volume Layout Change (`/var/lib/postgresql/18/docker`)
- **Date / Linked Action**: `2026-11-20` (`ACT-074` / `#252`, `#272`)
- **Observed Symptom**: Mounting a named volume at `/var/lib/postgresql/data` or running `pg_basebackup -D /var/lib/postgresql/data` failed on `postgres:18` (`PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2)`).
- **Root Cause Analysis**: Starting with the official `postgres:18` image, `VOLUME` moved to `/var/lib/postgresql` and default `PGDATA` moved to `/var/lib/postgresql/18/docker` to support `pg_upgrade` across major versions.
- **Applied Change / Fix**: Mounted all PG 18 Docker Compose volumes at `/var/lib/postgresql` (`docker-compose-pg18-{streaming,logical,birep}.yml`) and parameterized standby bootstrap via `PGD="${PGDATA:-/var/lib/postgresql/18/docker}"`.
- **Result & Non-Regression Test**: `docker compose -f <file> config --quiet` and live `tests/test_pg18_{streaming,logical,birep}.sh` pass cleanly.

### RCA-065 -- PostgreSQL 18 `io_method=io_uring` Blocked by Default Docker Seccomp (`Operation not permitted`)
- **Date / Linked Action**: `2026-11-20` (`ACT-074` / `#254`, `#272`)
- **Observed Symptom**: Starting `postgres:18` with `-c io_method=io_uring` under default Docker security profiles failed immediately with `Operation not permitted` (`EPERM`).
- **Root Cause Analysis**: Docker's default seccomp profile blocks `io_uring_setup` / `io_uring_enter` syscalls for container isolation, whereas PG 18 defaults to portable `io_method=worker` (`io_workers=3`).
- **Applied Change / Fix**: Kept PG 18 default `io_method=worker` across all PG 18 stacks without relaxing container seccomp (`security_opt: seccomp=unconfined`) and benchmarked `worker` vs `sync` A/B (`-18.5%` cold post-checkpoint seq-scan latency: `829.4 ms` vs `1018.3 ms`).
- **Result & Non-Regression Test**: Verified live in `tests/test_pg18_streaming.sh` (`io_method=worker`, `data_checksums=on`).

### RCA-066 -- PostgreSQL 18.6 Logical Sequence Sync Deferred to PG 19 (`SQLSTATE 42601`)
- **Date / Linked Action**: `2026-11-20` (`ACT-074` / `#256`, `#258`, `#272`)
- **Observed Symptom**: Executing `CREATE PUBLICATION ... FOR ALL SEQUENCES` and `ALTER SUBSCRIPTION ... REFRESH SEQUENCES` on PostgreSQL 18.6 raised `SQLSTATE 42601` (`syntax error`), and `T18` failover left logical subscriber sequences at `1|false` -> `SQLSTATE 23505`.
- **Root Cause Analysis**: Native logical sequence replication was reverted/deferred past PostgreSQL 18 to PostgreSQL 19, while physical streaming replication continues to sync sequence state via WAL (`66|true` -> `next_id=67`).
- **Applied Change / Fix**: Verified and logged `SQLSTATE 42601` explicitly in `tests/test_pg18_logical.sh`, adopted native PG 18 `uuidv7()` primary keys (`id UUID PRIMARY KEY DEFAULT uuidv7()`) for collision-free `pg18-birep` active-active inserts (`50/50` converged, `2,066.70 TPS` on `H_append_only_insert`), and kept stepped sequences (`INCREMENT BY 2`) for integer tables.
- **Result & Non-Regression Test**: Verified live in `tests/test_pg18_logical.sh` and `tests/test_pg18_birep.sh`.

### RCA-067 -- MySQL 8.4 LTS InnoDB Cluster Breaking Configuration & SQL Changes and PG 18 Standalone `PGDATA` Mount
- **Date / Linked Action**: `2026-11-20` (`ACT-075` / `#275`, `#276`, `#286`)
- **Observed Symptom**: Upgrading `docker-compose-innodb-cluster.yml` from EOL `mysql:8.0` to `mysql:8.4` causes fatal startup and bootstrap errors if legacy MySQL 8.0 Group Replication options (`transaction-write-set-extraction=XXHASH64`) and `RESET MASTER;` remain; similarly, adding standalone `postgres18` (`postgres:18`) with `/var/lib/postgresql/data` fails under PG 18's new `PGDATA` layout (see `RCA-064`).
- **Root Cause Analysis**: MySQL 8.4 LTS removed the deprecated `transaction_write_set_extraction` system variable (XXHASH64 is now unconditional) and removed `RESET MASTER` in favor of `RESET BINARY LOGS AND GTIDS`. Official `postgres:18` Docker images require mounting volumes at `/var/lib/postgresql`.
- **Applied Change / Fix**: Removed `transaction-write-set-extraction=XXHASH64` from `conf/innodb-cluster/node{1,2,3}.cnf`, replaced `RESET MASTER;` with `RESET BINARY LOGS AND GTIDS;` in `conf/innodb-cluster/setup_cluster.sh`, and mounted `postgres_18_data` at `/var/lib/postgresql` in `docker-compose.yml` (PR `#277`).
- **Result & Non-Regression Test**: `docker compose config`, `bash -n`, `test_no_eol_images_and_pg18_volume_mount` in `tests/test_repo_static.py` (PR `#283`), and CI `test-and-validate` pass green.

### RCA-068 -- YT Cluster 1.21.3 Default Commit Mode Is Sync-2PC Majority (`cc=half`), Not Async
- **Date / Linked Action**: `2026-11-20` (`ACT-076` / `#288`, `#292`, `#300`)
- **Observed Symptom**: Initial `dbinvent/yt:1.21.3` benchmarks produced `20.63 TPS` (`A_single_rw`) and `10.69 TPS` (`B2_overlap_rw`) with `0` balance drift and `86 rows/s` on 10k bulk inserts (`T11`), matching synchronous 2PC latency rather than asynchronous replication.
- **Root Cause Analysis**: Inspecting `yt_info('d')` revealed `def_cluster_commit={"at_least":0,"mode":1}` (`half` = 2-of-3 synchronous XA 2PC with `NO_SC`), combined with per-row `yt_synchronize()` trigger capture.
- **Applied Change / Fix**: Documented `cc=half` as the default `yt-cluster` profile and added an explicit async comparison mode (`cc=nodes>=0`, `yt-cluster-async`) in `scripts/bench_yt_runner.sh` (`A_single_rw=41.45 TPS`, `B2_overlap=55.03 TPS`, `D_hot=163.01 TPS` with `0` drift, `F_wan25=4.78 TPS`).
- **Result & Non-Regression Test**: Verified live in `scripts/yt_cluster/setup_yt_cluster.sh` and `scripts/bench_yt_runner.sh`.

### RCA-069 -- YT Cluster 1.21.3 `SAVEPOINT` Rollback (`0A000`) & Quorum Halt (`57P03`) Behavior
- **Date / Linked Action**: `2026-11-20` (`ACT-076` / `#290`, `#300`)
- **Observed Symptom**: Rolling back a `SAVEPOINT` over replicated writes failed at `COMMIT` with `SQLSTATE 0A000`, and losing 2 of 3 nodes halted writes with `SQLSTATE 57P03` (`YT-E1852 Not enough working nodes`).
- **Root Cause Analysis**: `yt_cluster 1.21` does not support partial subtransaction rollback over captured write triggers (`0A000`), and `min_cluster_size=2` enforces quorum writes on a 3-node cluster (`57P03`).
- **Applied Change / Fix**: Codified both behaviors as explicit `EXPECTED_LIMITATION` assertions in `tests/test_yt_cluster.sh` (`L5`, `L8`) alongside `55409` lost-update/SERIAL conflict detection (`L1`, `L3`) and `40001` unique-constraint arbitration (`L4`).
- **Result & Non-Regression Test**: Verified live in `tests/test_yt_cluster.sh` (`SQLSTATE`s `0A000;40001;55409;57P03`).

### RCA-070 -- YT Cluster Stale `/var/run/postgresql/.s.YT.5432.pid` `YT-E1104` Crash-Loop Caveat After Unclean Stop
- **Date / Linked Action**: `2026-11-20` (`ACT-076` / `#290`, `#300`)
- **Observed Symptom**: Following an unclean `SIGKILL` crash (`T16`), if the restarted container reuses the PID recorded in `/var/run/postgresql/.s.YT.5432.pid`, `ytserv` can exit in a crash-loop with `YT-E1104`.
- **Root Cause Analysis**: The `dbinvent/yt:1.21.3` entrypoint does not clear a stale `.s.YT.5432.pid` lock file when PID reuse occurs across rapid container restarts.
- **Applied Change / Fix**: Documented the operational caveat in `documentation/pg_multimaster{,_fr}.md` and verified clean `RPO=0` recovery (`20/20`) and `T_REVERT` (`DROP EXTENSION yt_cluster CASCADE;`) in `tests/test_yt_cluster.sh`.
- **Result & Non-Regression Test**: `T16` (`RPO=0`, `post_restart=20/20`) and `T_REVERT` (`5/5` intact -> `6/6` plain PG write) verified in `tests/test_yt_cluster.sh`.

### RCA-071 -- YT Async WAN Leader Bypass & `sbtest` `55000` (`#336`)
- **Date / Linked Action**: `2026-11-21` (`ACT-077` / `#336`)
- **Observed Symptom**: Non-monotonic WAN (`yt1`) and `E3_wo` `55000` after `E_rw`.
- **Root Cause Analysis**: Leader `yt1` bypassed `netem`; async `E_rw` locked `sbtest`.
- **Applied Change / Fix**: `r_wan` hits non-Leader `wn`; `r_sb` retry + `prep_sb()` + `YT_ASYNC_MISSING_ONLY=1`.
- **Result & Non-Regression Test**: WAN `8.47->4.78->2.90`, `E3=133.55`, 36/36 `drift=0`; tagged in `v2.4.1` (`#343`, `#345`).

---

### RCA-072 -- Fragmented CLI, Standalone Lifecycle & Missing Engine Routing (`#302`–`#317`)
- **Date / Linked Action**: `2026-11-21` (`ACT-080` / Audit `#1`–`#4`, `#8`, `#11`)
- **Observed Symptom**: `mdb client` hardcoded `mysql`; standalone up/down omitted `--profile`, `traefik`, auto-PKI, `mariadb_ssh:004`, and EOL rejection; `Status`/`Info` ignored `mdb_*` prefixes/HA files; `mdb logs` dropped `--profile`; `mdb mycnf` overwrote `~/.my.cnf` without backup.
- **Root Cause Analysis**: Legacy subcommands targeted root `docker-compose.yml` and MySQL assumptions instead of a shared registry and uniform profile/compose helpers.
- **Applied Change / Fix**: Added `pkg/catalog`, `pkg/docker` profile/multi-compose/image helpers (`#303`, `#305`), engine-aware `mdb client`, `UpProfile` / `--profile "*"`, dynamic `ProjectName()`, `mdb logs` `--profile`, `0600` `~/.my.cnf.bak`, unified `./mdb`/`mdb.cmd`, `setup`/`lint`/`test`, and `pg17-baseline` (`#310`–`#317`, `#333`, `#335`).
- **Result & Non-Regression Test**: `go test ./...` (11/11) + CI `test-and-validate` pass.

---

### RCA-073 -- Non-Portable Timing, `.env` Fallbacks, Runner UX & Doc Drift (`#318`–`#354`)
- **Date / Linked Action**: `2026-11-21` (`ACT-080`, `ACT-081` / Audit `#5`–`#7`, `#9`–`#10`, `#12`)
- **Observed Symptom**: `mdb bench` skipped PG/Mongo; `Makefile` broke without `.env` `DB_ROOT_PASSWORD`, used GNU `timeout 120s` (non-macOS), required host `psql` in `pgpool-status`, and slept fixed `15–30s`; `interactive_runner.py` had PG `inject`, wrong `make info` check, broken HTML escape, and EN retry text in FR; docs omitted `pg17-baseline`/YT details and listed stale `haproxy:2.9-alpine`/`cockroachdb:v24.3.0`.
- **Root Cause Analysis**: Shell/Python tooling and EN/FR docs diverged from the Go catalog and multi-engine Compose stacks without readiness polling or parity checks.
- **Applied Change / Fix**: Added multi-engine `mdb bench` (`#320`), bilingual Go wizard (`#324`, `#329`), portable `seq 1 60` + `docker exec` polling + `rootpass` fallback + `pgpool-status` `docker exec` + `MONGO_NODES` (`setup_rs.sh`) + 13 PG stack targets (`#307`, `#322`, `#325`, `#330`, `#338`), Python fixes/deprecation (`#332`), and EN/FR docs + `v2.5.0` (`#340`, `#341`, `#346`, `#349`, `#350`, `#352`, `#354`).
- **Result & Non-Regression Test**: `unittest` (52 ran: 46 ok, 6 skipped), `go test ./...` (11/11), `release_notes.py --tag v2.5.0 --check`, and CI `test-and-validate` green.

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

### IMP-006 — External OpenSSL Subprocess Invocation in Golang Architecture
- **Why It Is a Dead-End**: Invoking `openssl` via shell scripts or Go `os/exec` introduces external binary dependencies, cross-platform pathing issues on Windows, and error-masking risks.
- **Adopted Decision**: Utilize native Go `crypto/x509`, `crypto/rsa`, and `encoding/pem` in `pkg/pki` for all CA and SAN certificate generation with programmatic file mode `0600`.

### IMP-007 — Docker Go SDK Dependency Overhead
- **Why It Is a Dead-End**: Importing `github.com/docker/docker/client` introduces massive transitive dependency trees (>25MB overhead, moby conflicts).
- **Adopted Decision**: Wrap `docker` CLI via standard library `os/exec` abstraction (`CommandRunner` interface) allowing hermetic unit testing without live daemons.

### IMP-008 — Direct Modification of `.github/workflows/*.yml` via OAuth Token Without `workflow` Scope
- **Why It Is a Dead-End**: GitHub rejects pushes modifying `.github/workflows/ci.yml` when authenticated via an OAuth App token lacking the `workflow` scope.
- **Adopted Decision**: Wire new CI test suites (`make test-go`, `python3 -m unittest`) directly into the `Makefile` targets (`make test-config`, `make check-ssl-all`) already invoked by `.github/workflows/ci.yml`.

### IMP-009 — Uncoordinated `SERIAL` & LWW for Non-Commutative Balance Increments (`balance = balance + delta`)
- **Why It Is a Dead-End**: Live Suite D hot-row contention proved async LWW loses or diverges balances (`pg-birep` `-71,063` diverged, `pgedge` LWW `-278,698`, `bucardo` `-531,620`).
- **Adopted Decision**: Require `spock.delta_apply` (`log_old_value=true`, achieving `0` drift at `1,837.64 TPS`) or `40001`-retried consensus engines (`yugabyte`, `cockroach`, `citus`).

### IMP-010 -- Promoting a `pg-logical` Subscriber Without `setval()` or Relying on Co-Located Bucardo Metadata for HA
- **Why It Is a Dead-End**: `T18` proved native logical subscribers leave sequences at `1|false` (`SQLSTATE 23505` on first post-failover insert), while `T16` proved `SIGKILL` on the Bucardo metadata-hosting node drops synchronization of peer writes made during the outage (`20/21`).
- **Adopted Decision**: Use physical streaming (`pg-streaming` / `patroni`) or Raft consensus (`yugabyte` / `cockroach`) for transparent HA failover, or enforce scripted `setval()` promotion runbooks for logical replicas.

### IMP-011 -- Image-Baked SSH Host Keys, `privileged: true` Lab Containers & Per-Version Mongo Setup Copies
- **Why It Is a Dead-End**: Baking `ssh-keygen -A` into `Dockerfile` distributes identical private host keys to every image consumer; `privileged: true` over-grants host capabilities to MariaDB containers; duplicating `setup_rs.sh` into `setup_rs_mongo8.sh` caused drift.
- **Adopted Decision**: Generate SSH host keys lazily at container startup (`scripts/start_mariadb.sh`), drop `privileged: true`, and parameterize `conf/mongo-rs/setup_rs.sh` via `MONGO_NODES` (PR `#243`).

### IMP-012 -- Enabling `io_method=io_uring` via Unconfined Docker Seccomp or Relying on PG 18 `FOR ALL SEQUENCES`
- **Why It Is a Dead-End**: Disabling Docker seccomp to expose `io_uring` weakens container isolation (`RCA-065`), and `FOR ALL SEQUENCES` raises `SQLSTATE 42601` in PG 18.6 (`RCA-066`).
- **Adopted Decision**: Use PG 18's default `io_method=worker` under standard seccomp and use native `uuidv7()` or stepped sequences for active-active logical schemas until PG 19 ships logical sequence sync.

### IMP-013 -- Retaining End-of-Life Database and Proxy Images in Active Stacks
- **Why It Is a Dead-End**: Keeping EOL images (`mysql:5.7` EOL 2023-10-31, `mysql:8.0` EOL 2026-04-30, `mysql:9.6` EOL 2026-04-21, `mariadb:10.6` EOL 2026-07-06, `percona/percona-server:8.0` EOL 2026-04-30, `traefik:v2.11` EOL 2026-09-07, `haproxy:2.9-alpine` EOL 2025-03-21) exposes lab users to unpatched CVEs and obsolete configuration patterns.
- **Adopted Decision**: Removed all 7 EOL images from Compose stacks and `interactive_runner.py`, replaced legacy `Makefile` targets with explicit EOL notices + recommended replacements (`exit 1`), documented official EOL dates in EN/FR matrices (PR `#278`, `#281`), and enforced non-regression via `test_no_eol_images_and_pg18_volume_mount` (PR `#283`).

### IMP-014 -- Treating YT Cluster Default Mode as High-Throughput Async or Relying on `SAVEPOINT` Rollbacks
- **Why It Is a Dead-End**: Default `cc=half` sync-2PC caps write throughput near `20.6`–`67.8 TPS` (`86 rows/s` bulk), and `SAVEPOINT` rollbacks over writes fail at `COMMIT` (`SQLSTATE 0A000`).
- **Adopted Decision**: Benchmark both default `cc=half` and async `cc=nodes>=0` explicitly in `scripts/bench_yt_runner.sh` and avoid write-containing `SAVEPOINT`s in YT Cluster workloads.

---

### IMP-015 -- Retaining Python `interactive_runner.py` / `mysql_docker.py` as Primary Entry Points
- **Why It Is a Dead-End**: Dual Python/Go/Makefile paths caused engine drift, missing Windows parity, and duplicated environment lists.
- **Adopted Decision**: Consolidate all operations under `./mdb` (`mdb.cmd` on Windows) and `pkg/catalog`, keeping `Makefile` targets as thin compatibility wrappers and printing deprecation notices in Python runners (`#332`).

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

### APP-004 — In-Memory Self-Signed x509 PKI Engine for Laboratory Isolation
- **Target Files**: `pkg/pki/cert.go`, `cmd/mdb/main.go`
- **Nature & Justification**: Hermetic self-signed CA and SAN leaf certificates using Go `crypto/x509` and RSA 2048 without external OpenSSL or public CAs.
- **Removal Condition**: Production deployments using external corporate CA or ACME automation.

### APP-005 — Hermetic CommandRunner Interface for Docker Testing
- **Target Files**: `pkg/docker/client.go`, `pkg/docker/docker_test.go`
- **Nature & Justification**: In-memory `MockCommandRunner` allows unit tests to execute hermetically without requiring a live Docker daemon.
- **Removal Condition**: Live integration tests run against real containers in Phase 3.

### APP-006 — CommandExecutor Pattern for Database Health Drivers
- **Target Files**: `pkg/dbclient/dbclient.go`, `pkg/dbclient/dbclient_test.go`
- **Nature & Justification**: Verification runs via `CommandExecutor` container exec abstraction or TCP ping to maintain zero external SDK bloat.
- **Removal Condition**: Native database drivers adopted if direct connection pooling becomes necessary in production.

### APP-007 — Pure Go Embedded HTML Reporting via Standard Library embed.FS
- **Target Files**: `pkg/report/report.go`, `pkg/report/templates/report.html`
- **Nature & Justification**: Standalone HTML reporting bundles styles and layout into Go binary via `embed.FS` without external node/npm build chains or remote CDN script loading for offline lab reproducibility.
- **Removal Condition**: Standalone SPA front-end if interactive web UI is requested in future phases.

### APP-008 (APP-010) — Static SSH Port Mapping Scheme Across Clustered Topologies
- **Target Files**: `docker-compose-galera.yml`, `scripts/gen_profiles.sh`, `documentation/architecture.md`
- **Nature & Justification**: Clustered topologies assign static host port ranges for node SSH access (Replication: 23001-23003; Galera: 24001-24003) to enable direct container inspection and debugging without collision.
- **Removal Condition**: Dynamic port allocation via SDN or container orchestrator (Kubernetes/Nomad) when deploying in production.

### APP-009 — Sourced Test Library Exemption from Standalone Strict Mode Assertion
- **Target Files**: `tests/lib/common.sh`, `tests/test_project_governance_rules.py`
- **Nature & Justification**: `tests/lib/common.sh` is a sourced helper library that initializes environment, assertions, and reporting functions across test suites. While it sets `set -euo pipefail` at line 5, it is explicitly exempted from standalone script execution requirements.
- **Removal Condition**: Maintained permanently as an explicit architectural design pattern for sourced bash libraries.

### APP-010 — English Localization for Patroni and MariaDB Startup Scripts
- **Target Files**: `scripts/patroni/entrypoint_etcd.sh`, `scripts/patroni/entrypoint_node.sh`, `scripts/patroni/generate_certs.sh`, `scripts/start_mariadb.sh`
- **Nature & Justification**: Standardized comments and startup status logs to English across Patroni cluster orchestrators and MariaDB entrypoint scripts, removing legacy French comments and echo statements.
- **Removal Condition**: Permanent governance requirement for repository standardization.

### APP-011 — English Localization for Galera and Replication Test Reports
- **Target Files**: `tests/test_galera.sh`, `tests/test_repli.sh`, `tests/test_lb_galera.sh`
- **Nature & Justification**: Standardized Markdown table headers, HTML summary cards, and visual architecture diagram labels to English across Galera, Replication, and Load Balancer test suites, replacing legacy French phrases ("Nature du Test", "Résultat Réel", "Attendu", "Statut").
- **Removal Condition**: Permanent governance requirement for repository standardization.

### APP-012 — Automated Verification of English Localization across All Shell Scripts
- **Target Files**: `tests/test_haproxy_galera.sh`, `tests/test_project_governance_rules.py`
- **Nature & Justification**: Standardized HAProxy Galera test script and HTML reporting into English, and implemented permanent automated unit test `test_no_french_table_headers_remain` to mechanically guarantee that no legacy French strings ("Nature du Test", "Résultat Réel", "Génération de l'autorité") are introduced in `scripts/` or `tests/`.
- **Removal Condition**: Permanent governance rule enforcing English-only engineering standards.

### APP-013 — Comprehensive Automated Detection of Residual French Strings
- **Target Files**: `tests/test_project_governance_rules.py`, all `scripts/**/*.sh`, `tests/**/*.sh`
- **Nature & Justification**: Expanded `test_no_french_table_headers_remain` with dual scanning (French accented character set `[éèêëàâçîïôûù...]` and word-bounded regex covering all known French UI, log, and comment patterns).
- **Removal Condition**: Permanent governance rule enforcing English-only repository policy.

### APP-014 — Documentation Parity and Port Reconciliation (Milestone 3 PR 1)
- **Target Files**: `documentation/architecture.md`, `documentation/supported_products.md`, `documentation/supported_products_fr.md`, `documentation/makefile.md`, `documentation/INDEX.md`
- **Nature & Justification**: Reconciled historical documentation drifts against actual Compose port mappings (Galera Node 1 SSH 24001, Replication 3411-3413) and synchronized `makefile.md` to document all HA cluster targets (Patroni, PgPool-II, InnoDB Cluster, MongoDB), Go CLI commands, MySQLTuner targets, and E2E verification suites while removing phantom `pgpass`/`pgclient` targets and duplicate `make start`.
- **Removal Condition**: Permanent documentation baseline aligned with current repository capabilities.

### APP-015 — Go CLI and Automation Scripts Reference (Milestone 3 PR 2)
- **Target Files**: `README.md`, `documentation/scripts.md`
- **Nature & Justification**: Added comprehensive documentation for the Go `mdb` CLI orchestrator (v2.0) commands (`version`, `config`, `topologies`, `up`, `down`, `status`, `test`, `bench`, `pki`, `report`), automation utilities (`gen_pki.sh`, `run_mysqltuner.sh`, `aggregate_reports.sh`), and integrated living governance registers (`docs/ACTION_LOGBOOK.md`, `docs/RCA_REGISTER.md`) into `README.md`.
- **Removal Condition**: Permanent documentation baseline for v2.0 orchestrator and scripts.

### APP-016 — Makefile and Configuration Governance Scanning & Build-Time Injection
- **Target Files**: `Makefile`, `cmd/mdb/main.go`, `tests/test_project_governance_rules.py`
- **Nature & Justification**: Standardized Patroni lifecycle echo statements to English in `Makefile`, implemented automated governance test scanning `Makefile` and `conf/` for French strings, and added compile-time `-X main.version=...` injection in `make build-go` with synchronized fallback in `cmd/mdb/main.go` verified by automated unit tests.
- **Removal Condition**: Permanent governance rule enforcing English localization and version integrity.

### APP-017 — Mongo 8 TLS Fallback & Dedicated PKI
- **Target Files**: `conf/mongo-rs/setup_rs.sh` (unified from `setup_rs_mongo8.sh` in PR `#243`), `docker-compose-mongo8-rs.yml`
- **Nature & Justification**: Added cert mounts and 3-tier fallback in setup.
- **Removal Condition**: Permanent pattern for lab/CI connection resilience.

### APP-018 — Patroni HAProxy Client TLS & PgBouncer Port Exposure
- **Target Files**: `docker-compose-patroni.yml`, `documentation/patroni_cluster.md`
- **Nature & Justification**: Mutual TLS is active internally across nodes/ETCD; HAProxy (5000/5001) and PgBouncer (6432) allow plaintext client connections in lab mode.
- **Removal Condition**: Enforce client TLS termination at HAProxy in production.

### APP-019 — Single-Host `tc netem 25ms` WAN Approximation & `PG_SCALE=2` Lab Scaling
- **Target Files**: `scripts/bench_pg_multimaster.sh`, `scripts/bench_pg_lib.py`
- **Nature & Justification**: Sequential execution on a single 20-vCPU / 16.4 GiB host at `PG_SCALE=2` with `tc netem 25ms` models symmetric WAN RTT without hardware multi-region NIC contention.
- **Removal Condition**: Re-run Suites A–F across dedicated multi-AZ VMs at higher scale factors (`PG_SCALE >= 50`).

### APP-020 -- V2 Extended Matrix (`T11`-`T18`) & V2 Sweep Single-Host Laboratory Execution
- **Target Files**: `scripts/test_pg_extended_matrix.sh`, `scripts/test_pg_extended_lib.py`, `scripts/bench_pg_v2_runner.sh`, `scripts/bench_pg_v2_lib.py`
- **Nature & Justification**: `T11`-`T18` probes, concurrency sweep (`G_conc_c1..c32`), extended sysbench (`E2`-`E4`), append-only inserts (`H`), and WAN sweep (`10/25/50ms` via `tc netem`) execute sequentially on one Docker host for clean cross-engine isolation.
- **Removal Condition**: Re-execute V2 sweeps across dedicated multi-node VMs with physical inter-AZ RTT and NVMe storage.

### APP-021 -- Stdlib Regex Compose Fallback in Bare CI & Dry-Run Release Dispatch Default
- **Target Files**: `tests/test_repo_static.py`, `.github/workflows/release.yml`
- **Nature & Justification**: When `PyYAML` is absent on bare CI runners, `test_repo_static.py` falls back to stdlib regex checks (`services:` + `image:`/`build:`) to keep zero-dependency CI fast; manual `workflow_dispatch` defaults to dry-run (`publish=false`) to prevent accidental releases.
- **Removal Condition**: Install `PyYAML` in CI if deep schema linting is added; keep dry-run default permanently.

### APP-022 -- Single-Host PG 18.6 Sequential Benchmark Execution (`PG_SCALE=2`, `io_method=worker`)
- **Target Files**: `scripts/bench_pg18_runner.sh`, `scripts/bench_pg18_lib.py`
- **Nature & Justification**: PG 18.6 benchmarks (87 rows across 5 topologies) execute sequentially on one Docker host with `PG_SCALE=2`, default `io_method=worker`, `data_checksums=on`, and `tc netem` WAN emulation for controlled PG 17 vs PG 18 comparison.
- **Removal Condition**: Re-run on dedicated multi-node bare-metal/VM hosts with NVMe and Linux kernel `io_uring` enabled.

### APP-023 -- Retaining Supported `mariadb:11.8` in `Dockerfile` and `postgres:17` in Patroni/PgPool/Citus/pgEdge
- **Target Files**: `Dockerfile`, `docker-compose-patroni.yml`, `docker-compose-pgpool.yml`, `docker-compose-citus.yml`, `docker-compose-pgedge.yml`
- **Nature & Justification**: `mariadb:11.8` (EOL 2028-06-04) and `postgres:17` (EOL 2029-11-08) remain actively supported upstream, so upgrading Galera/Repli base image to `mariadb:12.3` or migrating PG 17 clusters to PG 18 (requiring PgPool-II 4.7) was deferred to avoid unverified live-cluster regressions.
- **Removal Condition**: Upgrade once live E2E cluster tests for `mariadb:12.3` Galera/Repli and PG 18 Citus/pgEdge/PgPool-II 4.7 are verified.

### APP-024 -- Single-Host YT Cluster 1.21.3 Sequential PoC (`dbinvent/yt:1.21.3`, `PG_SCALE=2`)
- **Target Files**: `docker-compose-yt-cluster.yml`, `scripts/bench_yt_runner.sh`, `tests/test_yt_cluster.sh`
- **Nature & Justification**: Evaluates the official prebuilt `dbinvent/yt:1.21.3` (PolyForm Noncommercial / Commercial `ytserv` + MIT `yt_cluster` core) on a single Docker host at `PG_SCALE=2` with `tc netem` WAN emulation and ephemeral lab credentials.
- **Removal Condition**: Re-evaluate on multi-host VMs with production licensing and persistent secret management if deployed beyond PoC evaluation.

---

### APP-025 -- Unset `.env` `DB_ROOT_PASSWORD` Laboratory Fallback (`rootpass`)
- **Target Files**: `Makefile`, `cmd/mdb/`, `pkg/docker/`
- **Nature & Justification**: Falls back to `rootpass` with an explicit warning when `.env` omits `DB_ROOT_PASSWORD`, preventing first-run setup errors in local labs.
- **Removal Condition**: Enforce mandatory secret injection (`.env` / Vault / KeePass) for any shared or non-lab deployment.

---

### APP-026 -- YT Cluster 1.21.3 License Split & Jepsen 1.20.1 `cursor-stability` Caveat
- **Target Files**: `documentation/pg_multimaster.md`, `documentation/pg_multimaster_fr.md`, `documentation/supported_products.md`, `documentation/supported_products_fr.md`
- **Nature & Justification**: `dbinvent/yt:1.21.3` bundles MIT-licensed `yt_cluster` (`DBinvent/yt-cluster-lite`, single-DB leaf rejecting `0A000` on additional DBs) with PolyForm Noncommercial 1.0.0 / Commercial `ytserv` + `ytctl`; Jepsen passed 49/49 nemesis tests under `1.20.1` (`2` of `51` skipped: `cursor-stability` unsupported on `1.20.1`, added in `1.21.0`).
- **Removal Condition**: Re-verify license terms and full-51 `1.21.x` Jepsen results prior to commercial or multi-database adoption.

---

### APP-027 -- Local Windows `go test -race` Requires CGO `gcc` Toolchain
- **Target Files**: `AGENTS.md`, `.github/workflows/`
- **Nature & Justification**: Native Windows hosts run `go test ./...` without `-race` when `gcc` is absent; full `-race` verification executes on Linux CI (`test-and-validate`) and WSL.
- **Removal Condition**: Install MSYS2/mingw64 `gcc` if local Windows `-race` execution is required.

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

### IDEA-004 — Dynamic Topology Manifest Engine via YAML
- **Priority / Target**: `Low` · `pkg/topology/manifest.go`
- **Description**: Allow user-defined database topologies loaded dynamically from external YAML files without Go recompilation.

### IDEA-005 — Automated Performance Regression Gate via Sysbench Metrics
- **Priority / Target**: `High` · `pkg/bench/sysbench.go`, `cmd/mdb`
- **Description**: Automatically compare parsed sysbench TPS and 95th percentile latency against historical baseline thresholds, failing CI on performance degradation.

### IDEA-006 — Documentation-to-Compose Port and Target Drift Linter
- **Priority / Target**: `Medium` · `tests/test_documentation_drift.py`
- **Description**: Static governance test asserting compose ports and Makefile targets are documented in `documentation/*.md`.

### IDEA-007 — Native Go Verifiers for Multi-Master Topologies in `pkg/dbclient/`
- **Priority / Target**: `Medium` · `pkg/dbclient/`
- **Description**: Extend `NewVerifier()` to inspect `spock.sub_show_status()`, `pg_subscription`, `bucardo status`, `pg_dist_node`, CockroachDB `gossip_nodes`, and YugabyteDB `yb_servers()`.

### IDEA-008 -- Native Go Verifiers for `pg-streaming` and `pg-logical` in `pkg/dbclient/`
- **Priority / Target**: `Medium` | `pkg/dbclient/`
- **Description**: Add dedicated verifier branches inspecting `pg_stat_replication` (`state='streaming'`, `sync_state`) for `pg-streaming` and `pg_subscription` / `pg_stat_subscription_stats` for `pg-logical`.

### IDEA-009 -- Scheduled Live Multi-Node Docker E2E Matrix on Self-Hosted CI Runners
- **Priority / Target**: `Medium` | `.github/workflows/ci.yml`
- **Description**: Run live cluster E2E suites (`test_lab.py`, `test_failover.sh`, `make test-all-topologies`) on a scheduled self-hosted runner with Docker daemon capacity so live container paths are verified continuously alongside deterministic unit/static tests.

### IDEA-010 -- PostgreSQL 19 Logical Sequence Sync (`FOR ALL SEQUENCES`) & Unit Tests for `bench_pg18_lib.py`
- **Priority / Target**: `Medium` | `tests/test_pg_libs.py`, `docker-compose-pg19-*.yml`
- **Description**: Add deterministic unit tests for `scripts/bench_pg18_lib.py` and add a PostgreSQL 19 stack once GA to validate native `FOR ALL SEQUENCES` / `REFRESH SEQUENCES` logical failover parity.

### IDEA-011 -- Dedicated Go Verifier Branch for `yt-cluster` (`yt_info('o')`)
- **Priority / Target**: `Low` | `pkg/dbclient/postgres.go`
- **Description**: Extend `PostgresVerifier` to inspect `SELECT yt_info('o');` directly and report active YT Cluster leader and working node count (`3` expected).

### IDEA-012 -- Retire Legacy `mysql_docker.py` & `interactive_runner.py` in `v3.0`
- **Priority / Target**: `Medium` | `mysql_docker.py`, `interactive_runner.py`
- **Description**: Remove deprecated Python wrappers once external CI pipelines and course materials fully adopt `./mdb` / `mdb.cmd`.

### IDEA-013 -- Full Parity Matrix Automated Drift Check (`pkg/catalog` vs `Makefile` vs Docs)
- **Priority / Target**: `Low` | `tests/`
- **Description**: Assert every environment key in `pkg/catalog` has matching `Makefile` wrapper targets and EN/FR documentation coverage.


