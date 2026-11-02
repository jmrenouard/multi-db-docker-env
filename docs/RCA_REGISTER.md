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

