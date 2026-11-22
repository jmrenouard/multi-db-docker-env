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

### RCA-074 -- Cross-Topology `ComposePS` Orphan Leak & Windows `WSLENV` Stripping
- **Date / Linked Action**: `2026-11-21` (`ACT-083` / Issue `#357`)
- **Observed Symptom**: `mdb status <topo>` returned sibling-stack containers as running; Windows WSL `bash.exe` dropped `extraEnv` (`MONGO_NODES`, `CERT_DIR`, `DB_ROOT_PASSWORD`).
- **Root Cause Analysis**: Docker Compose v2 `ps` defaults `--orphans=true` and `ComposePS` omitted `profilesFor(files)`; WSL strips Windows env vars absent from `WSLENV`.
- **Applied Change / Fix**: Added `--orphans=false` to `ComposePS`/`ComposePSStatus` (plus `profilesFor(files)` in `ComposePS`) and added `docker.MergeEnv` forwarding `extraEnv` keys via `WSLENV` on Windows `bash`.
- **Result & Non-Regression Test**: Verified in `pkg/docker/docker_test.go` and `cmd/mdb/main_test.go`.

### RCA-075 -- Missing `DB_ROOT_PASSWORD` in Setup/Suite Scripts, `test_lab.py` Hang & `DefaultService` Drift
- **Date / Linked Action**: `2026-11-21` (`ACT-084` / Issue `#359`)
- **Observed Symptom**: Setup/`--suite` scripts defaulted PG passwords to `pg_poc_ephemeral` when `.env` was absent while containers used `rootpass`; `make test` hung on `tests/test_lab.py` under WSL; `mdb config` reported `mariadb118` instead of `mariadb114`.
- **Root Cause Analysis**: `BaseTopology.Up`/`runSetupCmd`/`runTestCmd --suite` omitted `DB_ROOT_PASSWORD` when unset; `test_lab.py` lacked connect/subprocess timeouts; `DefaultConfig().DefaultService` was stale.
- **Applied Change / Fix**: Propagated `DB_ROOT_PASSWORD` when unset, passed positional node args to `tests/test_mongo_rs.sh`, added connect/5s timeouts + `TimeoutExpired` handling in `tests/test_lab.py`, and aligned `DefaultService` to `mariadb114`.
- **Result & Non-Regression Test**: Verified in `pkg/topology/topology_test.go`, `cmd/mdb/main_test.go`, `pkg/config/config_test.go`, and `tests/test_python_audit_fixes.py`.

### RCA-076 -- Hardcoded Host Ports `3306`/`5432` Colliding with Local DB Daemons
- **Date / Linked Action**: `2026-11-21` (`ACT-085` / Issue `#362`)
- **Observed Symptom**: `traefik-db-proxy` (`docker-compose.yml`) and `haproxy_galera` (`docker-compose-galera.yml`) failed to bind `0.0.0.0:3306` when host/WSL `mariadb.service` occupied `3306`.
- **Root Cause Analysis**: Only `TRAEFIK_DASHBOARD_PORT` was parameterized, while `3306` and `5432` were hardcoded across Compose, `mdb mycnf`, `tests/test_lab.py`, and Galera HAProxy tests.
- **Applied Change / Fix**: Parameterized `${TRAEFIK_MYSQL_PORT:-3306}`, `${TRAEFIK_PG_PORT:-5432}`, and `${GALERA_LB_PORT:-3306}` in Compose and tests; updated `mdb mycnf` to write `port=${TRAEFIK_MYSQL_PORT:-3306}` and `mdb doctor` to warn when localhost `3306`/`5432` is already bound with override hints.
- **Result & Non-Regression Test**: Verified in `cmd/mdb/main_test.go`, `tests/test_python_audit_fixes.py`, and `mdb lint`.

### RCA-077 -- Hardcoded `repli`/`galera` Names, `-sN` Stripping `\G` Labels & Windows `mdb clean` Mount Colon Split
- **Date / Linked Action**: `2026-11-21` (`ACT-086` / Issue `#365`)
- **Observed Symptom**: `mdb up repli`/`galera` timed out (`No such container: mariadb_01`), `mdb test repli` always returned `UNHEALTHY`, `tests/test_repli.sh` exited 1 at line 135, and `mdb clean repli` on Windows failed with `invalid mode: /workspace`.
- **Root Cause Analysis**: Compose omits `container_name` on `repli`/`galera` nodes; `-sN` suppresses vertical `\G` column labels; `-v C:\...:/workspace` splits on the Windows drive colon under WSL `docker.cmd`.
- **Applied Change / Fix**: Added `resolveNodeContainer` in `pkg/topology`, surfaced setup `stdout` when `stderr` is empty, added `execVerticalQuery` (no `-sN`) in `pkg/dbclient/mysql.go` and `tests/test_repli.sh`, and switched `removeGlobs` to `--mount` with `/mnt/<drive>` WSL fallback (plus slash normalization in `runInjectCmd`).
- **Result & Non-Regression Test**: Verified in `pkg/topology/topology_test.go`, `pkg/dbclient/dbclient_test.go`, and `cmd/mdb/main_test.go`.

### RCA-078 -- Nonexistent `pgpool:4.6` Image, Windows `0777` SSL Keys, Broken `pgpool`/`cockroach`/`yugabyte` Verifiers & `yb_node3` Join Race
- **Date / Linked Action**: `2026-11-21` (`ACT-087` / Issue `#369`)
- **Observed Symptom**: `mdb up pgpool` failed with `manifest for pgpool/pgpool:4.6 not found` (and Windows drvfs mounts expose `server.key` as `0777` to PostgreSQL); `mdb test pgpool` targeted port `5432` instead of `9999`; `mdb test cockroach`/`yugabyte` exited 127 trying `psql`; `yb_node3` crashed once (`Restarts=1`) racing `yb_node2` on `add_master`.
- **Root Cause Analysis**: Docker Hub only publishes `pgpool/pgpool` up to `4.4.3`; PostgreSQL rejects world-readable keys; `PostgresVerifier` omitted `pgpool` `-h 127.0.0.1 -p 9999` and dedicated `cockroach`/`yugabyte` CLI paths; `yb_node2` lacked a healthcheck gating `yb_node3`.
- **Applied Change / Fix**: Pinned `pgpool/pgpool:4.4.3` (Compose + `documentation/pgpool_cluster.md`), copied `pg_node1..3` SSL keys to container-local `0600` `postgres`-owned files, updated `PostgresVerifier` (`pgpool` `127.0.0.1:9999`, `cockroach`, `yugabyte`), and serialized `yb_node2 -> yb_node3` via healthcheck in `docker-compose-yugabyte.yml`.
- **Result & Non-Regression Test**: Verified in `pkg/dbclient/postgres_mongo_test.go` and `mdb lint`.

### RCA-079 -- InnoDB `drvfs` `0777` `.cnf`, Bucardo Restart Race, YT `t16_sigkill_crash` WAL Reload Window & pgEdge Reload Warning
- **Date / Linked Action**: `2026-11-21` (`ACT-088` / Issue `#373`)
- **Observed Symptom**: `mdb up innodb` ignored world-writable `group_replication.cnf` on Windows/WSL2 `drvfs` (`@@gtid_mode=OFF`); `mdb setup bucardo` failed (`bucardo.mcp.pid exists`) leaving the daemon stopped; `tests/test_yt_cluster.sh:149` failed `57P03`/`YT-E1465` right after restarting `yt2`; `pgedge` logged `55P02`/`F0000` on `pg_reload_conf()`.
- **Root Cause Analysis**: Windows `drvfs` exposes bind mounts as `0777`; `bucardo stop` is asynchronous; `yt2` needs 2-3s after `wcl()` to reload WAL files; `pgedge`'s image `postgresql.conf` sets `logging_collector = on` while compose runs `off`.
- **Applied Change / Fix**: Mounted InnoDB `.cnf` to `.src:ro` + copied with `chmod 0644` and exposed `START GROUP_REPLICATION` stderr; waited up to 15s for `bucardo.mcp.pid` removal; added a 15-attempt retry in `t16_sigkill_crash` + `.env` sourcing in YT scripts; aligned `logging_collector = off` in `setup_pgedge.sh`.
- **Result & Non-Regression Test**: Verified in `tests/test_python_audit_fixes.py` (`test_cluster_setup_and_sigkill_guards`) and `mdb lint`.

### RCA-080 -- `mdb report` Standalone Resolution, `mdb bench` MySQL/PG Failures & `mdb inject` MySQL Warning
- **Date / Linked Action**: `2026-11-21` (`ACT-089` / Issue `#376`)
- **Observed Symptom**: `mdb report <standalone>` produced `clusters: 0`; `mdb bench` exited 127 on standalone MySQL/MariaDB/Percona and failed `database "root" does not exist` on PG; `mdb inject` printed `mariadb: command not found` on MySQL.
- **Root Cause Analysis**: `mdb report` bypassed `activeCatalog()` engine/container lookup; `mdb bench` ran `sysbench` directly inside upstream DB images without `sysbench` or `sbtest` setup and omitted `postgres` dbname in `pgbench`; `runInjectCmd` invoked `mariadb` without `command -v`.
- **Applied Change / Fix**: Shared `resolveVerifierTarget` between `mdb test` and `mdb report`; added `runMySQLSysbench` (creates `sbtest`, runs `prepare`+`run` in-container or via transient `--network` container with TLS fallback) and `postgres` dbname in `pgbench`; gated `mariadb` in `runInjectCmd`.
- **Result & Non-Regression Test**: Verified in `cmd/mdb/main_test.go`.

### RCA-081 -- Windows `docker` `WSLENV` Stripping, `pgpool` Substring Collision & Replication Setup `PANIC`
- **Date / Linked Action**: `2026-11-21` (`ACT-090` / Issue `#381`)
- **Observed Symptom**: `mdb.cmd up galera`/`pgpool` dropped `MARIADB_GALERA_BOOTSTRAP=1`/`DB_ROOT_PASSWORD` via WSL `docker.cmd`; `mdb test`/`client pgpool` matched `haproxy_pgpool` (exit 127); `setup_replication.sh` caused `PANIC: pg_control Permission denied` leaving `pg_node2` down.
- **Root Cause Analysis**: `MergeEnv` only set `WSLENV` for `bash`; `docker ps --filter name=pgpool` returned `haproxy_pgpool` first; `setup_replication.sh` wiped live PGDATA and ran `pg_basebackup` as `root`; `docker-compose-pgpool.yml` defaulted password to `postgres` instead of `rootpass`.
- **Applied Change / Fix**: Added `docker`/`docker.exe`/`docker.cmd` to `MergeEnv` `WSLENV` (and `RunCombined`); added exact-match `pickContainerName` in `resolveContainer`/`resolveEnvContainer`; aligned `pgpool` `rootpass` default and switched `setup_replication.sh` to clean `docker stop` + `gosu postgres pg_basebackup` + `docker restart pgpool`.
- **Result & Non-Regression Test**: Verified in `pkg/docker/docker_test.go`, `cmd/mdb/main_test.go`, and `mdb lint`.

### RCA-082 -- Standalone `pfs.cnf` `drvfs` Ignore & Galera 9P NTFS `galera.cache` I/O Timeout
- **Date / Linked Action**: `2026-11-21` (`ACT-091` / Issue `#387`)
- **Observed Symptom**: Standalone MySQL/MariaDB/Percona ignored `0777` bind-mounted `pfs.cnf` on Windows/WSL2 (`@@performance_schema=0` on MariaDB, default `history_size=10` on MySQL); `galera_01` stalled `>120s` in kernel disk I/O allocating 512MB `galera.cache` over 9P drvfs NTFS and logged `lower_case_table_names=2`.
- **Root Cause Analysis**: Windows `drvfs` exposes bind-mounted files as world-writable `0777` and incurs heavy 9P latency for database data directories (`./gdatadir_01..03`); `conf/gcustom_{1,2,3}.cnf` set `gcache.size=512M` vs `tests/test_galera.sh`'s expected `128M`.
- **Applied Change / Fix**: Replaced all 14 standalone `pfs.cnf` bind mounts in `docker-compose.yml` with shared `x-pfs-command: &pfs-command` CLI flags; switched `docker-compose-galera.yml` to named Docker volumes (`galera_data_01..03`) and set `gcache.size=128M` in `conf/gcustom_{1,2,3}.cnf`.
- **Result & Non-Regression Test**: Verified in `tests/test_python_audit_fixes.py` (`test_cluster_setup_and_sigkill_guards`) and `mdb lint`.

### RCA-083 -- Citus Scatter/Deadlock, CRDB `root` `ALTER ROLE` Bypass, Yugabyte `COPY` OOM & pgEdge Pre-Reset Drain
- **Date / Linked Action**: `2026-11-21` (`ACT-093`–`ACT-095` / Issues `#368`, `#372`, `#380`)
- **Observed Symptom**: Citus scattered single-key `pgbench` across 32 shards (`40.56 TPS`) and hit distributed deadlocks on multi-table `DROP`; CRDB `ALTER ROLE ALL SET default_transaction_isolation='read committed'` failed silently for `root` (`42501`); Yugabyte `pgbench -i` `COPY` risked OOM at `PG_SCALE=20`; `pgedge` delta-apply resets diverged if run before peer drain; `sysbench` crashed on YT `55409`.
- **Root Cause Analysis**: `bid`-distributed `pgbench_accounts`/`tellers` prevented single-shard pushdown on `WHERE aid=:aid`/`tid=:tid`; CRDB blocks `ALTER ROLE` on `root` and has no cluster GUC for default isolation; `3072m` Yugabyte containers enforce a `1.5 GiB` tserver hard limit; `spock.delta_apply` computes `-old` deltas relative to local peer state; `sysbench` `drv_pgsql.c` treats only `40001`/`40P01`/`23505` as built-in ignorable errors.
- **Applied Change / Fix**: Switched Citus to 1-shard-per-statement routing + separate autocommit `DROP`s; created dedicated admin role `bench` for `cockroach-rc`; added `batch=50000` chunked `INSERT` loader (`//` for CRDB) + `CACHE 1000` sequences; drained peers before `pgedge` `hs[0]` reset; routed `sysbench` through `/tmp/sb_wrap.lua` `sql_error_ignorable` (`55409`/`40001`/`40P01` + `ROLLBACK`).
- **Result & Non-Regression Test**: Empirically verified on live images and guarded by `TestBenchPgOptimizedLib` (`tests/test_pg_libs.py`).

### RCA-084 -- `mdb inject` `/tmp` `tmpfs` Shadowing & `haproxy_galera` Recreating `galera_01`
- **Date / Linked Action**: `2026-11-21` (`ACT-097` / Issue `#392`)
- **Observed Symptom**: `mdb inject employees galera` failed (`cd: can't cd to /tmp/employees`, exit 2), and `mdb up galera` silently recreated `galera_01` when starting `haproxy_galera`, causing an immediate `mdb test galera` to race and fail exit 127.
- **Root Cause Analysis**: `docker-compose-galera.yml` mounts `tmpfs` at `/tmp` (hiding `docker cp` writes to `/tmp`), and `haproxy_galera` declares `depends_on: [galera_01, galera_02, galera_03]` so `up -d haproxy_galera` without `MARIADB_GALERA_BOOTSTRAP=1` triggered Compose recreation of `galera_01`.
- **Applied Change / Fix**: Switched `runInjectCmd` (`cmd/mdb/commands_admin.go`) to `/var/tmp/` and added `--no-deps` when starting `haproxy_galera` in `pkg/topology/galera.go`.
- **Result & Non-Regression Test**: Verified in `pkg/topology/topology_test.go` and `tests/test_python_audit_fixes.py`.

### RCA-085 -- Bucardo `sbtest4` Peer Wait Timeout & Runner `.env` Credential Precedence (`v2.6.1`)
- **Date / Linked Action**: `2026-11-21` (`ACT-098` / Issue `#394`)
- **Observed Symptom**: (1) `bench_pg_optimized_runner.sh` timed out on `bucardo` during `run_sysbench_opt` (`RuntimeError: Timeout waiting for sbtest4 count=25000 on bucardo_node2`); (2) `pg17-logical` setup failed authentication when a local `.env` existed and credentials were not pre-exported before invoking the runner.
- **Root Cause Analysis**: (1) Trigger-based Bucardo replicates `sync_pgbench` only (`pgbench_*`), does not replicate DDL or `sbtest1..4` to `bucardo_node2`, and `run_sysbench_opt` queries only `hs[0]`, yet `_sb_prepare` waited for `sbtest4` on `hs[1:]`; (2) `bench_pg_optimized_runner.sh` defaulted `PG_PASS`/`DB_ROOT_PASSWORD` to `pg_poc_ephemeral` before sourcing `.env`, causing `docker compose` to receive the fallback while `scripts/*/setup_*.sh` sourced `.env`.
- **Applied Change / Fix**: Excluded `"bucardo"` in `_sb_prepare` (`scripts/bench_pg_opt_workloads.py`), added `cd "$BENCH_ROOT"` + `[ -f .env ] && { set -a; . ./.env; set +a; }` and `DB_ROOT_PASSWORD`-first precedence before `export PG_PASS` in `scripts/bench_pg_optimized_runner.sh`, and released `v2.6.1`.
- **Result & Non-Regression Test**: Verified in `tests/test_pg_libs.py` (`test_sb_prepare_skips_bucardo_slave_wait`, `test_optimized_runner_sources_dotenv_before_pg_pass`), `go test -count=1 ./...`, `bash ./tests/test_config.sh`, and `release_notes.py --tag v2.6.1 --check`.

### RCA-086 -- Missing Self-Contained Patroni Dockerfiles, `conf/patroni.yml` & Root Supervisor Coupling
- **Date / Linked Action**: `2026-11-21` (`ACT-100` / Issue `#396`)
- **Observed Symptom**: `docker-compose-patroni.yml` referenced `patroni-rhel8-{etcd,postgresql,haproxy}:latest` images with no Dockerfiles or `conf/patroni.yml`, while `conf/supervisord-patroni.conf` ran as `root` with an unused `sshd` program and `entrypoint_node.sh` ran unconditional `chown`.
- **Root Cause Analysis**: Patroni originally relied on external RHEL8 builds; running `supervisord` as root violated `IMP-005`, invoking `/usr/sbin/sshd` without `openssh-server` caused crash loops, and Patroni needed `PATRONI_*` env mapping to avoid hardcoded secrets in `/etc/patroni.yml`.
- **Applied Change / Fix**: Added pinned non-root `scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}` and secret-free `conf/patroni.yml`; switched `conf/supervisord-patroni.conf` to `user=postgres` stdout logging without `sshd`; updated `scripts/patroni/entrypoint_node.sh` for non-root cert staging and `PATRONI_*` credential export.
- **Result & Non-Regression Test**: All 3 images built cleanly with 0 HIGH/WARN/INFO on `lint_dockerfile.py`, and `go test`, `unittest`, and `mdb lint` pass.

### RCA-087 -- HAProxy mTLS REST Check Rejection, Startup Race & Default Password Drift in Patroni
- **Date / Linked Action**: `2026-11-21` (`ACT-102` / Issue `#401`)
- **Observed Symptom**: Under `PATRONI_VERIFY_CLIENT=required`, HAProxy health checks without a client certificate fail TLS handshakes; starting `node1..3` and `haproxy` concurrently without `service_healthy` triggered etcd `3.0.0`/`/v3alpha` startup races and HAProxy `ECONNREFUSED` alerts; `POSTGRES_PASSWORD` defaulted to `postgres` instead of repo default `rootpass`.
- **Root Cause Analysis**: `conf/haproxy-patroni.cfg` used `verify none` without `crt /certs/haproxy.pem` or `resolvers docker` and logged to non-existent `/dev/log`; `docker-compose-patroni.yml` omitted `build:` sections and `condition: service_healthy` dependencies.
- **Applied Change / Fix**: Wired `build:`, `condition: service_healthy`, and `POSTGRES_PASSWORD=${DB_ROOT_PASSWORD:-rootpass}` in `docker-compose-patroni.yml`; configured HAProxy stdout logging, `resolvers docker`, and mTLS REST checks (`verify required ca-file /certs/ca.crt crt /certs/haproxy.pem`).
- **Result & Non-Regression Test**: Live `mdb up patroni` reaches 7/7 healthy containers with HAProxy Layer7 mTLS 200 OK checks (`4-7ms`) and zero `ECONNREFUSED` alerts; `mdb lint` and `go test` pass.

### RCA-088 -- Patroni 4.x `streaming`/`Primary` Verifier Gap & Hardcoded Network/HTTP Checks in `test_patroni.sh`
- **Date / Linked Action**: `2026-11-21` (`ACT-103` / Issue `#402`)
- **Observed Symptom**: `mdb test patroni` undercounted Patroni 4.1.5 replicas reporting `State: "streaming"` (degrading 3/3 to 1/3); `tests/test_patroni.sh` hardcoded `multi-db-docker-env_patroni_net`, omitted `PGPASSWORD` in `run_psql`, used GNU-only `grep -oP`, and queried `http://localhost:7000/` against HTTPS+auth HAProxy stats.
- **Root Cause Analysis**: `pkg/dbclient/postgres.go` checked only `running` and `Leader` (omitting Patroni 3.x/4.x `streaming` and `Primary`); `tests/test_patroni.sh` predated worktree compose project names, TLS-authenticated `pg_hba.conf`, and HTTPS HAProxy stats.
- **Applied Change / Fix**: Updated `verifyPatroni` in `pkg/dbclient/postgres.go` for `running`/`streaming` and `Leader`/`Primary` (+ unit tests); updated `tests/test_patroni.sh` and `tests/test_failover.sh` (dynamic network inspection, `PGPASSWORD`, `Leader|Primary`, `awk`, HTTPS stats); added static Patroni Dockerfile/mTLS test in `tests/test_repo_static.py`.
- **Result & Non-Regression Test**: Verified live `mdb test patroni` HEALTHY `3/3`, `--suite` `14/14`, failover `1/1`, `TestPostgresVerifier_VerifyCluster`, and `test_patroni_self_contained_dockerfiles_and_mtls`.

### RCA-089 -- Benchmark Runner `.env` Bypass, Ignored `BENCH_OUT_DIR` & Windows `TemporaryDirectory` Lock
- **Date / Linked Action**: `2026-11-22` (`ACT-107` / Issue `#418`)
- **Observed Symptom**: V1/V2/PG18/YT/extended runners skipped `.env` or passed `.env.example`, causing auth mismatches against `setup_*.sh`; V1 and optimized runners ignored `BENCH_OUT_DIR`; `bench_pg_multimaster.sh` left CSV read handle open; Windows `TemporaryDirectory` cleanup raised `PermissionError`.
- **Root Cause Analysis**: Five runners lacked `cd "$BENCH_ROOT"` + `.env` sourcing + `DB_ROOT_PASSWORD`-first precedence; V1/opt runners lacked `BENCH_OUT_DIR` wiring; WSL `bash.EXE` held `cwd` during temp cleanup on Windows.
- **Applied Change / Fix**: Added `cd` + `.env` sourcing + `DB_ROOT_PASSWORD` precedence across all 5 runners and `test_pg_extended_matrix.sh`, removed `--env-file .env.example` and closed/atomized CSV I/O in `bench_pg_multimaster.sh`, wired `BENCH_OUT_DIR` in V1/optimized runners, and passed `ignore_cleanup_errors=True` in `tests/test_pg_libs.py`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest` (`0` errors), `go test -count=1 ./...`, `bash -n`, and `tests/test_config.sh`.

### RCA-090 -- Missing V2 Summary CSV `FileNotFoundError`, Unclosed CSV Handles, Silent `wcnt` Timeout & `YT_RETRY_PY` Disconnect Crash
- **Date / Linked Action**: `2026-11-22` (`ACT-108` / Issue `#420`)
- **Observed Symptom**: `append_summary_preserving` crashed with `FileNotFoundError` when `benchmark_summary.csv` did not exist; `upsert_modular_csv`/`upsert_pg18_csv` leaked file handles (`ResourceWarning`) and wrote non-atomically; `wcnt` returned `None` on 45s timeout; `YT_RETRY_PY` crashed worker threads on `c.rollback()` after disconnect and interpolated password in DSN strings.
- **Root Cause Analysis**: V2/PG18 CSV code lacked existence guards, `with` blocks, and `.csv.tmp` rename; `wcnt` omitted a final `RuntimeError`; `YT_RETRY_PY` lacked connection-drop `rollback()`/reconnect handling and kwarg connection arguments.
- **Applied Change / Fix**: Fixed `append_summary_preserving` (missing-file `COLS` header + atomic write), consolidated `write_csv_atomic`, `upsert_csv`, and hardened `YT_RETRY_PY` in `scripts/bench_pg_lib.py`, raised `RuntimeError` in `wcnt`, and delegated `upsert_modular_csv`/`upsert_pg18_csv` to `upsert_csv`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest` (`0` ResourceWarnings), `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-091 -- Duplicated `YT_RETRY_PY`, Unquoted YT `sysbench` Password & Unclosed YT Resume CSV
- **Date / Linked Action**: `2026-11-22` (`ACT-109` / Issue `#422`)
- **Observed Symptom**: `bench_yt_runner.sh` and `bench_pg_opt_common.py` duplicated `YT_RETRY_PY`, `wcnt_opt`, and atomic CSV code; `bench_yt_runner.sh` interpolated `PW` directly in `bash -c` `sysbench` strings and left `ex_path.open()` unclosed.
- **Root Cause Analysis**: YT/Opt runners copied inline `YT_RETRY_PY` and CSV logic instead of importing from `bench_pg_lib.py`.
- **Applied Change / Fix**: Imported `YT_RETRY_PY`, `write_csv_atomic`, `upsert_csv`, and `wcnt` from `bench_pg_lib.py`, passed `--pgsql-password="$PGPASSWORD"` via `bc(..., PW, ...)` in `bench_yt_runner.sh`, and wrapped `ex_path.open()` in `with`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, `bash -n`, and `tests/test_config.sh`.

### RCA-092 -- Swallowed `pgbench` Exit Codes, Unsampled `C_multinode_ro` Logs & `pg-birep` `reset_ds` Drift Leak
- **Date / Linked Action**: `2026-11-22` (`ACT-110` / Issue `#424`)
- **Observed Symptom**: `pb_run`/`pb_run_opt` masked `pgbench` crashes with `||true` and logged `PASS_CONVERGED` at `0.0` TPS; `C_multinode_ro` wrote ~1M lines without sampling; `reset_ds` skipped `history` drain and `hs[1]` reset on `pg-birep`; `run_sb` left `pw` unquoted.
- **Root Cause Analysis**: Stream exit codes were discarded (`||true`/`wait||true`), `C_multinode_ro` omitted `--sampling-rate`, and `reset_ds` reset only `hs[0]`.
- **Applied Change / Fix**: Hardened `pb_run` in `bench_pg_lib.py` (stream exit capture, abort/`tps==0` `RuntimeError`, `--sampling-rate=0.05` on `C_multinode_ro`, `/tmp/pb_*` `finally` cleanup), added `history` pre-drain + `hs[1:]` balance reset in `reset_ds`, and quoted `run_sb` password via `PGPASSWORD`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-093 -- Duplicated `pb_run_opt`/`conv_chk_opt` Loops & Missing `pg18-birep` Pre-Drain in `reset_ds`
- **Date / Linked Action**: `2026-11-22` (`ACT-111` / Issue `#426`)
- **Observed Symptom**: `bench_pg_opt_common.py` still ran its own copy of `pb_run_opt` (`||true`, unsampled `C_multinode_ro`, unclosed handles) and `conv_chk_opt`, while `reset_ds` pre-drain skipped `pg18-birep`.
- **Root Cause Analysis**: Shared helpers were split across `bench_pg_lib.py` and `bench_pg_opt_common.py` without callback injection for unit test patches.
- **Applied Change / Fix**: Added `assert_zero_containers`, `tc_netem`, `ref_sub`, generalized `conv_chk`, and `pg18-birep` pre-drain/reset to `bench_pg_lib.py` with `sh_fn`/`pq_fn`/`bc_fn` hooks, and rewired `bench_pg_opt_common.py` to delegate directly.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest`, `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-094 -- Fake `--env` Compose Flag & Missing `wsl` `WSLENV`
- **Date / Action**: `2026-11-21` (`ACT-112` / `#412`)
- **Symptom**: `ComposeUpProfiles` used `--env` stripped by `extractComposeEnv`; `mergeEnv` missed `wsl`/`wsl.exe`; `*Client` lacked `ResolveContainer`.
- **5 Whys**: (1) `runCompose` used `Run` vs `RunWithEnv`. (2) Tests checked `--env` in `Calls`. (3) `mergeEnv` missed `wsl`.
- **Fix**: `runCompose` (`compose.go`); drop `extractComposeEnv`, `wsl`/`wsl.exe`, `ResolveContainer` (`client.go`); tests.
- **Test**: `docker_test.go`, `topology_test.go`, `go test ./...` (11/11), `mdb lint` pass.

### RCA-095 -- Unclosed `bench_pg_v2_runner.sh` Log Handle & Missing `bench_pg18_lib` / `ResourceWarning` Coverage
- **Date / Linked Action**: `2026-11-22` (`ACT-113` / Issue `#413`)
- **Observed Symptom**: `scripts/bench_pg_v2_runner.sh` opened `(LOGD / f"{t}.log").open(...)` manually outside a `with` context manager (risking leaked descriptors if `run_topo` failed before or inside `finally` cleanup), `scripts/bench_pg18_lib.py` lacked dedicated unit tests in `tests/test_pg_libs.py`, and no static guard enforced `.open(` context-manager usage across `scripts/*.py` and `scripts/*.sh`.
- **Root Cause Analysis**: Conditional logging in `run_topo` used `... if is_new else None` with manual `logf.close()` instead of `contextlib.nullcontext()`, while unclosed `.open(` handles escaped CI without `-W error::ResourceWarning` and static `.open(` checks.
- **Applied Change / Fix**: Imported `nullcontext` in `scripts/bench_pg_v2_runner.sh` and wrapped `run_topo(topo, logf)` in a `with` block in the topology loop; added `TestBenchPg18Lib` (`assert_zero_pg18_containers`, `pb_run_pg18`, `upsert_pg18_csv`) and `TestBenchResourceHygiene` (`ResourceWarning` check on `upsert_modular_csv`/`upsert_pg18_csv` + static `.open(` `with`-guard scan) in `tests/test_pg_libs.py`.
- **Result & Non-Regression Test**: Verified `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped in `test_lab.py`), `go test -count=1 ./...` (`11/11`), and `go run ./cmd/mdb lint` (`70` scripts, `21` compose files).

### RCA-096 -- Hardcoded HAProxy Stats Credentials & Unquoted Paths / `700` Cert Dir in Patroni `generate_certs.sh`
- **Date / Linked Action**: `2026-11-22` (`ACT-114` / Issue `#414`)
- **Observed Symptom**: `conf/haproxy-patroni.cfg` and `tests/test_patroni.sh` hardcoded `admin:adminpass` for the HAProxy HTTPS stats endpoint without Compose/`.env.example` parameterization, while `scripts/patroni/generate_certs.sh` left `$CERT_DIR`, `$name`, `$cn`, and `$1` unquoted and used `chmod 700 "$CERT_DIR"` instead of `755` (`IMP-003` / `04_best_practices.md`).
- **Root Cause Analysis**: HAProxy stats auth was originally authored before `.env` credential decoupling, and `generate_certs.sh` omitted quotes around path expansions while tightening the parent certificate directory to `700` rather than restricting only private keys (`*.key`, `haproxy.pem`) to `600`.
- **Applied Change / Fix**: Parameterized HAProxy stats auth via `"$HAPROXY_STATS_AUTH"` in `conf/haproxy-patroni.cfg`, `docker-compose-patroni.yml` (`${HAPROXY_STATS_AUTH:-admin:adminpass}`), `tests/test_patroni.sh`, and `.env.example`; quoted all variable expansions and aligned `chmod 755 "$CERT_DIR"` in `scripts/patroni/generate_certs.sh`; added static assertions in `tests/test_repo_static.py`.
- **Result & Non-Regression Test**: Verified live `haproxy -c -V` and Basic Auth enforcement (`200`/`401`) inside `patroni-rhel8-haproxy:latest`, live `generate_certs.sh` execution with spaces in `CERT_DIR`, `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped), `go test -count=1 ./...` (`11/11`), and `go run ./cmd/mdb lint` (`70` scripts, `21` compose files).

### RCA-097 -- Premature `sbtest1..4` Drop, Silent `srsubstate='r'` Timeout & Opt Bi-Dir Drift Leak
- **Date / Linked Action**: `2026-11-22` (`ACT-115` / Issue `#428`)
- **Observed Symptom**: `_sb_cleanup` slept a fixed 2s before dropping `sbtest1..4`; `_sb_prepare` exited the `srsubstate='r'` loop silently on timeout; `reset_ds_opt` skipped `history` drain and peer resets on `pg-birep`/`pg18-birep`; `sysbench` interpolated `pw` unquoted.
- **Root Cause Analysis**: Logical cleanup relied on wall-clock sleeps instead of `pg_stat_replication` `replay_lsn`, subscription prep omitted a timeout exception, and `reset_ds_opt` handled `pgedge` only.
- **Applied Change / Fix**: Added `wait_wal_replay`, `wait_sub_ready`, and `drop_sb_sub` in `bench_pg_lib.py`; updated `bench_pg_opt_workloads.py` to pass `pw` via `PGPASSWORD` with `shlex.quote`, pre-drain/reset `pg-birep`/`pg18-birep` peers, and enforce WAL/subscription readiness.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-098 -- Split Hardcoded Catalog Metadata & Inline Container Resolution into Atomic Slice 4A (`#415`)
- **Date / Linked Action**: `2026-11-22` (`ACT-116` / Issue `#415`)
- **Observed Symptom**: `pkg/catalog.Environment` lacked `SetupArgs`, `SetupEnv`, and `DefaultDB` fields (forcing hardcoded `mongo8` overrides and missing `labdb` defaults downstream), `pkg/interactive.VerifyEnvironment` duplicated `client.PS` resolution without exact-match preference or nil/empty guards, and combining all 5 cleanup slices produced `25,260` diff bytes (`> 15,000` `IMP-001` limit).
- **Root Cause Analysis**: Setup arguments/env and `POSTGRES_DB` defaults evolved per caller before `catalog.Environment` carried them, `interactive` predated `Client.ResolveContainer`, and multi-package dead-code deletion plus catalog refactoring exceeded a single `< 15,000`-byte PR.
- **Applied Change / Fix**: Executed sequential 3-PR split (`#415` -> `#432` -> `#433`); in Slice 4A (`#415`), added `DefaultDB`/`SetupArgs`/`SetupEnv` + `cloneEnv` copies + `mongo8` & 10 PG `labdb` entries in `pkg/catalog/catalog.go`, unit tests in `pkg/catalog/catalog_test.go`, and `client.ResolveContainer` in `pkg/interactive/steps.go`.
- **Result & Non-Regression Test**: Verified `go test -count=1 ./...` (`11/11`), `go vet ./...`, `go run ./cmd/mdb lint` (`70` scripts + `21` Compose files), and `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped in `test_lab.py`).

### RCA-099 -- Duplicated `run_wan_netem`/Logical Sysbench Loops & Unquoted Passwords in V2 Lib
- **Date / Linked Action**: `2026-11-22` (`ACT-117` / Issue `#434`)
- **Observed Symptom**: `bench_pg_v2_lib.py` duplicated `assert_zero_containers`, `_ref`, `_drop_sb_sub`, `_tc`, and `run_wan_netem`, interpolated `pw` in sysbench commands, slept 3s before dropping `sbtest1..4`, and ignored `srsubstate='r'` timeouts.
- **Root Cause Analysis**: V2 harness predated shared `bench_pg_lib` primitives and `PGPASSWORD` env injection.
- **Applied Change / Fix**: Added `run_wan_netem` in `bench_pg_lib.py`; delegated `bench_pg_opt_workloads.py` and `bench_pg_v2_lib.py` wrappers while passing `pw` via `PGPASSWORD` and enforcing `wait_wal_replay`/`wait_sub_ready`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-100 -- Duplicated PG 18 Helpers, Fixed `sleep 2` Teardown & Unquoted `sysbench` Credentials
- **Date / Linked Action**: `2026-11-22` (`ACT-118` / Issue `#437`)
- **Observed Symptom**: `bench_pg18_lib.py` duplicated `assert_zero_containers`, `_ref`, `conv_chk`, `_drop_sb_sub`, `_tc`, `run_wan_netem`, and `pg18-birep` peer reset, passed `pw` unquoted in `sysbench` commands, slept 2s before dropping `sbtest1..4`, and ignored `srsubstate='r'` timeouts.
- **Root Cause Analysis**: `bench_pg18_lib.py` copied V2 patterns instead of delegating to `bench_pg_lib.py` and using `PGPASSWORD` + `pg_stat_replication` / subscription checks.
- **Applied Change / Fix**: Rewired `bench_pg18_lib.py` wrappers to `bench_pg_lib.py`, removed redundant `pg18-birep` reset SQL, passed `pw` via `PGPASSWORD` + `shlex.quote`, and enforced `wait_sub_ready` and `wait_wal_replay`.
- **Result & Non-Regression Test**: Verified Windows + WSL Python `unittest` (`-W error::ResourceWarning`), `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-101 -- Duplicate Setup Maps, Inline Node Resolution & Dead `SysbenchRunner` (`#432`)
- **Date / Linked Action**: `2026-11-22` (`ACT-119` / Issue `#432`)
- **Observed Symptom**: `pkg/topology` duplicated 17 setup entries, `mongo8` args/env, and `resolveNodeContainer`, while `pkg/bench/sysbench.go` kept unused `CommandExecutor`/`SysbenchConfig`/`SysbenchRunner`.
- **Root Cause Analysis**: Topology predated `catalog` SSOT fields and `ResolveContainer`, and `SysbenchRunner` remained after benchmarks moved to Python/shell runners.
- **Applied Change / Fix**: Wired `BaseTopology.Up` to `catalog.DefaultCatalog().Lookup`, replaced `resolveNodeContainer` in `topology.go`/`galera.go` with `client.ResolveContainer`, and deleted dead `SysbenchRunner`/`mockExecutor` code in `pkg/bench/sysbench*.go`.
- **Result & Non-Regression Test**: Verified zero callers via `git grep`, `go test -count=1 ./...` (`11/11`), `go vet ./...`, `go run ./cmd/mdb lint` (`70` shell scripts + `21` Compose files), and `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped).

### RCA-102 -- Unbounded `pg_basebackup` Partial-Dir Loops, Unescaped `conninfo` & Reversed Password Order
- **Date / Linked Action**: `2026-11-22` (`ACT-120` / Issue `#440`)
- **Observed Symptom**: Streaming standbys wiped `PGDATA` once outside `until pg_basebackup`, risking infinite failure after partial clones; `primary_conninfo` left special password chars unescaped; Citus/YT prioritized `PG_LAB_PASSWORD` before `DB_ROOT_PASSWORD`.
- **Root Cause Analysis**: Standby entrypoints lacked per-attempt wipe, retry caps, and two-level libpq/GUC escaping; Citus/YT compose and scripts inverted repo fallback precedence.
- **Applied Change / Fix**: Moved `rm -rf` inside bounded 30-attempt `pg_basebackup` loops and escaped `primary_conninfo` via `esc_lp`/`esc_guc`; aligned `DB_ROOT_PASSWORD`-first order in `citus`/`yt-cluster`.
- **Result & Non-Regression Test**: Verified `docker compose config -q`, `bash -n`, Win/WSL `unittest`, `go test -count=1 ./...`, and `tests/test_config.sh`.

### RCA-103 -- Duplicate `mdb` Container Switch, `pickContainerName`, and Hardcoded `mongo8` Setup (`#433`)
- **Date / Linked Action**: `2026-11-22` (`ACT-121` / Issue `#433`)
- **Observed Symptom**: `cmd/mdb/main.go` kept a 45-line `defaultContainer` switch (missing standalone IDs and defaulting to `mariadb-11.8`), `pickContainerName`/`resolveContainer` duplicated `Client.ResolveContainer`, and `cmd/mdb/commands_lint.go` hardcoded `mongo8` `SetupArgs`/`SetupEnv`.
- **Root Cause Analysis**: CLI helpers predated `pkg/catalog` SSOT fields (`SetupArgs`, `SetupEnv`, standalone `Container` entries) and `docker.Client.ResolveContainer`.
- **Applied Change / Fix**: Delegated `defaultContainer` to `activeCatalog().Lookup` (fallback `mariadb-11.4`), deleted `pickContainerName`/`resolveContainer`, wired `resolveEnvContainer` to `client.ResolveContainer`, read `SetupArgs`/`SetupEnv` from `pkg/catalog` in `planSetup`/`runTestCmd`, and added unit checks in `cmd/mdb/main_test.go`.
- **Result & Non-Regression Test**: Verified zero callers via `git grep`, `go test -count=1 ./...` (`11/11`), `go vet ./...`, `go run ./cmd/mdb lint` (`70 shell scripts + 21 Compose files`), and `python -W error::ResourceWarning -m unittest discover -s tests -v` (`67` ran: `61` OK, `6` skipped).

### RCA-104 -- Unchecked YB/CRDB Quorum Timeouts, Exposed `.bucardorc` & Mutating `test_config.sh`
- **Date / Linked Action**: `2026-11-22` (`ACT-122` / Issue `#443`)
- **Observed Symptom**: `setup_cockroach.sh`/`setup_yugabyte.sh` continued after cluster timeout; `setup_bucardo.sh` left `/root/.bucardorc` mode `644` and expanded `$PG_PASS` unquoted; `setup_replication.sh` left SQL/shell creds unescaped; `test_pgpool.sh` hardcoded network + unbounded `curl`; `test_config.sh` called `chmod +x` during lint.
- **Root Cause Analysis**: Quorum loops lacked post-loop `exit 1` checks, setup scripts interpolated raw secrets, and `test_pgpool.sh`/`test_config.sh` used static names and side-effecting permission fixes.
- **Applied Change / Fix**: Added `INIT_OK`/`LIVE=3`/`TS_CNT=3` `exit 1` guards, `mktemp` + `v25.4`, `<<'EOF'` + `chmod 600` + `-e PGPASSWORD`, SQL/env escaping, `docker inspect` network + `--max-time 5`, and non-mutating `test_config.sh` check.
- **Result & Non-Regression Test**: Verified `bash -n`, `tests/test_config.sh`, Windows + WSL Python `unittest`, and `go test -count=1 ./...`.

### RCA-105 -- Halted `sub_from_node2` After Dual Conflicts, Fixed `/tmp/lb18.out`, `v24.3.0` Labels & Citus/YT Order
- **Date / Linked Action**: `2026-11-22` (`ACT-123` / Issue `#445`)
- **Observed Symptom**: `test_pg18_birep.sh` disabled `sub_from_node2` across both `9101` and `9201` blocks with one `skerr`, halting `N2->N1` apply on the second `23505`; it also wrote fixed `/tmp/lb18.out`, Citus/YT tests reversed `DB_ROOT_PASSWORD` fallback order, and Cockroach labels still said `v24.3.0`.
- **Root Cause Analysis**: Conflict skip lacked intermediate recovery before `9201`, `/tmp/lb18.out` lacked `mktemp` + `trap`, and test strings drifted after `v25.4`.
- **Applied Change / Fix**: Recovered and verified `sub_from_node2` after `9102` and `9201`, replaced `/tmp/lb18.out` with `mktemp` + `trap`, updated `v25.4` labels in `test_cockroach.sh`/`test_pg_extended_matrix.sh`, and aligned `DB_ROOT_PASSWORD`-first order in `test_citus.sh`/`test_yt_cluster.sh`. Remaining 7 fixed-`/tmp` test scripts split to a follow-up PR to stay `< 14,800` B.
- **Result & Non-Regression Test**: Verified `bash -n`, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

### RCA-106 -- Concurrent Fixed `/tmp/*.out` Collisions Across Seven PG Bash Test Suites
- **Date / Linked Action**: `2026-11-22` (`ACT-124` / Issue `#447`)
- **Observed Symptom**: Seven PG functional test scripts wrote host temporary logs to hardcoded `/tmp/{lb,lbuc,ll,ll18,ls,pg_sync_stall,pg18_sync_stall}.out` paths without `EXIT` cleanup traps.
- **Root Cause Analysis**: Ad-hoc output redirections omitted `mktemp` and `trap`, leaving stale artifacts on interruption and risking races across concurrent runs.
- **Applied Change / Fix**: Replaced all 7 hardcoded `/tmp/*.out` paths with `mktemp` variables guarded by `trap 'rm -f ...' EXIT`.
- **Result & Non-Regression Test**: Verified `bash -n`, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

### RCA-107 -- Duplicated PG 17/18 Physical Streaming Setup Scripts Across Directories
- **Date / Linked Action**: `2026-11-22` (`ACT-125` / Issue `#449`)
- **Observed Symptom**: `scripts/pg18_streaming/setup_pg18_streaming.sh` duplicated `scripts/pg_streaming/setup_pg_streaming.sh` verbatim apart from container, slot, and `io_method` output names.
- **Root Cause Analysis**: Separate PG 17 and PG 18 setup files lacked a shared helper library and parameterized runner, causing fixes to drift across versions.
- **Applied Change / Fix**: Extracted `scripts/pg_common/lib.sh` and `scripts/pg_common/setup_streaming.sh`, replacing both setup scripts with thin wrappers so all `Makefile`/`mdb`/benchmark callers stay compatible. Logical and birep parameterization split to a follow-up PR (`< 14,800` B).
- **Result & Non-Regression Test**: Verified `bash -n`, mock-docker smoke test, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

### RCA-108 -- `mdb inject` Poll, `mysql_node1` & Client Targets
- **Date / Linked Action**: `2026-11-22` (`ACT-126` / `#416`)
- **Observed Symptom**: `runInjectCmd` skipped timeout/cancel/`ResolveContainer`; `mysql_node1` hit PG; static CRDB/YB/`DefaultDB`.
- **Root Cause Analysis**: Poll lacked `ctx.Done()`/`!ready`; `"node"` before MySQL; static hosts/DB; `streamCommand` `func`.
- **Applied Change / Fix**: `streamCommand` var, `select`/`!ready`/`ResolveContainer`, MySQL-first, dynamic args, `shortcut:`, tests.
- **Result & Non-Regression Test**: `go test`, `go vet`, `mdb lint`, `unittest`, `release_notes.py` OK.

### RCA-109 -- Duplicated PG 17/18 Logical Replication Setup Scripts Across Directories
- **Date / Linked Action**: `2026-11-22` (`ACT-127` / Issue `#451`)
- **Observed Symptom**: `scripts/pg18_logical/setup_pg18_logical.sh` duplicated `scripts/pg_logical/setup_pg_logical.sh` verbatim apart from container, publication/subscription, and `substream` output names, and omitted backslash/space escaping in subscription `conninfo`.
- **Root Cause Analysis**: Separate PG 17 and PG 18 scripts reimplemented `run_sql`, polling loops, and `pg_subscription` creation independently.
- **Applied Change / Fix**: Extracted `scripts/pg_common/setup_logical.sh` backed by `lib.sh` (`wait_pg_nodes`, `esc_conn_val`) and converted both entry points into thin wrappers. Bidirectional birep parameterization follows in the next PR (`< 14,800` B).
- **Result & Non-Regression Test**: Verified `bash -n`, mock-docker smoke test, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

### RCA-110 -- Duplicated PG 17/18 Bidirectional Replication Setup Scripts Across Directories
- **Date / Linked Action**: `2026-11-22` (`ACT-128` / Issue `#454`)
- **Observed Symptom**: `scripts/pg18_birep/setup_pg18_birep.sh` duplicated `scripts/pg_birep/setup_birep.sh` verbatim apart from node and publication names, and omitted full libpq backslash/space escaping for `PG_PASS`.
- **Root Cause Analysis**: Parallel PG 17 and PG 18 bidirectional setups copied the entire sequence/table/subscription script instead of parameterizing a shared runner.
- **Applied Change / Fix**: Extracted `scripts/pg_common/setup_birep.sh` backed by `lib.sh` (`wait_pg_nodes`, `esc_conn_val`) and converted both entry points into thin wrappers, completing `#191.20`.
- **Result & Non-Regression Test**: Verified `bash -n`, mock-docker smoke test, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

### RCA-111 -- Missing HAProxy Docker Resolvers, L7 Checks & Distributed PG Healthchecks
- **Date / Linked Action**: `2026-11-22` (`ACT-129` / Issue `#456`)
- **Observed Symptom**: `pg_birep`, `pg18_birep`, and `pgedge` HAProxy configs lacked `resolvers docker` / `init-addr` (failing offline `-c` resolution and risking stale container IPs) and used raw TCP checks alongside `yugabyte`; `yb_node3`, `crdb_node1..3`, and all 5 HAProxy services lacked `healthcheck`s, `haproxy_yugabyte` waited only on `yb_node1`, and `haproxy_pgedge` omitted stats port `15459:8404`.
- **Root Cause Analysis**: Initial Compose/HAProxy templates omitted Docker DNS resolver stanzas, Layer-7 protocol probes, and uniform health/port definitions across stacks.
- **Applied Change / Fix**: Added `resolvers docker`, `init-addr last,libc,none resolvers docker`, and `option pgsql-check` across all PG/Yugabyte HAProxy configs; added `yb_node3` + `crdb_node1..3` (`/health?ready=1`) + all 5 HAProxy `:8404/stats` healthchecks, `yb_node1..3` `service_healthy` dependencies on `haproxy_yugabyte`, and `127.0.0.1:15459:8404` on `haproxy_pgedge`.
- **Result & Non-Regression Test**: Verified all 5 `haproxy -c -f` checks, `docker compose config -q`, `tests/test_config.sh`, Windows + WSL `-W error::ResourceWarning` `unittest`, and `go test -count=1 ./...`.

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

### IMP-016 -- Disabling `fsync`/`full_page_writes`, Adding `io_method` on PG 17, or Overriding YT `shared_preload_libraries`
- **Why It Is a Dead-End**: Disabling `fsync`/`full_page_writes` compromises durability (`RPO=0`); `io_method`/`io_workers` fails to boot on PostgreSQL 17; passing `-c shared_preload_libraries=...` on the YT Compose CLI erases `yt_cluster` from `conf.d/yt.conf`.
- **Adopted Decision**: Keep `fsync=on` and `full_page_writes=on` across all 13 PG Compose stacks, restrict `io_method`/`io_workers` strictly to PG 18 and YT Compose files (enforced by static test), and inject YT tuning via `YT_MAX_PREPARED=300` + PostgreSQL GUCs without `-c shared_preload_libraries`.

### IMP-017 -- Relying on External Pre-Built Patroni RHEL 8 Images Without In-Repo Dockerfiles
- **Why It Is a Dead-End**: `docker-compose-patroni.yml` referenced `patroni-rhel8-{etcd,postgresql,haproxy}:latest` with no local build definitions, leaving Patroni the lone skipped topology (30/31) in live E2E suites.
- **Adopted Decision**: Replaced external image reliance with pinned, non-root in-repo Dockerfiles (`scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}`), secret-free `conf/patroni.yml`, Compose `build:` + `service_healthy` ordering, `pkg/topology/patroni.go` auto-build, and unified `mdb images` orchestration (`#396`–`#405`), closing the 31/31 E2E gap.

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

### APP-018 — Patroni HAProxy Client TLS Termination & TCP Passthrough
- **Target Files**: `docker-compose-patroni.yml`, `conf/haproxy-patroni.cfg`, `documentation/patroni_cluster.md`
- **Nature & Justification**: Mutual TLS (`verify required`) is active across etcd (`:2379`), Patroni REST API (`:8008`), HAProxy stats (`:7000` HTTPS), and PostgreSQL (`hostssl`); HAProxy TCP frontends (`5000`/`5001`) forward PostgreSQL TLS connections to backend nodes without separate PgBouncer deployment.
- **Removal Condition**: Add dedicated PgBouncer service or HAProxy TLS termination if required in production.

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

### APP-028 -- Sequential 1-Stack-at-a-Time `PG_SCALE=20` Cap (`15 GiB` Host RAM) & Static Mocked Coverage
- **Target Files**: `docker-compose-{citus,yugabyte,cockroach}.yml`, `scripts/bench_pg_optimized_runner.sh`
- **Nature & Justification**: Host RAM (`15 GiB` total) permits running only one distributed cluster stack at a time (`citus` `2048m` x3, `yugabyte`/`cockroach` `3072m` x3); full 18-topology `PG_SCALE=20` matrix generation (`318` rows) is left to on-demand `make bench-pg-optimized`, while CI verifies `pg18-standalone` live smoke semantics plus deterministic unit mocks.
- **Removal Condition**: Execute `make bench-pg-optimized` on a dedicated `>= 16 GiB` Linux/WSL2 host to populate `reports/benchmark_optimized.csv`.

### APP-029 -- Non-Root `tc` File Capability in `scripts/Dockerfile.bench`
- **Target Files**: `scripts/Dockerfile.bench`
- **Nature & Justification**: `scripts/Dockerfile.bench` runs as unprivileged `USER postgres` and grants `cap_net_admin+ep` solely to `tc` so ephemeral benchmark containers (`--cap-add NET_ADMIN`) can inject WAN `netem` latency without running as `root`.
- **Removal Condition**: Permanent least-privilege pattern for containerized `pgbench`/`sysbench`/`tc netem` benchmarking.

### APP-030 -- Self-Contained 31-Image E2E Architecture, Legacy Patroni Tags & Native Linux Cert Ownership
- **Target Files**: `cmd/mdb/commands_images.go`, `scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}`, `scripts/patroni/generate_certs.sh`
- **Nature & Justification**: All 31 E2E images (`7` custom builds + `24` pinned upstream images) are centrally inventoried and verified by `./mdb images` and 21-compose parity tests; Patroni retains legacy `patroni-rhel8-{etcd,postgresql,haproxy}:latest` tags on pinned Debian/upstream bases (`quay.io/coreos/etcd:v3.5.17`, `postgres:17-bookworm`, `haproxy:lts`) for Compose compatibility. On native Linux hosts (non-drvfs), `generate_certs.sh` `0700`/`0600` host-owned keys may require UID/GID alignment for non-root `etcd`/`postgres`/`haproxy` containers.
- **Removal Condition**: Rename Patroni tags only in a breaking `v3.0` release; align host cert group readability if running rootless on native Linux.

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

### IDEA-014 -- Automated `PG_SCALE=20` Optimized vs Baseline Comparative Report Generator
- **Priority / Target**: `Medium` | `scripts/bench_pg_optimized_runner.sh`, `reports/`
- **Description**: Aggregate `reports/benchmark_optimized.csv` (`318` rows across 18 topologies) into comparative before/after delta tables and charts alongside `make bench-pg-v2` / `bench-pg18` / `bench-yt-cluster` baselines.



