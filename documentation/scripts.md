# Utility Scripts Documentation 📜

Reference and usage guide for repository shell, Go CLI, and Python helper scripts. See [architecture.md](architecture.md) for component layout.

## 💾 Backup & Restore

### Logical Backup (`mariadb-dump`)

- **[backup_logical.sh](../scripts/backup_logical.sh)**: Runs a compressed SQL dump.
  - Usage: `./backup_logical.sh <galera|repli> [database_name]`
  - Features: Runs `pigz` for fast compression and includes routines, triggers, and events.
- **[restore_logical.sh](../scripts/restore_logical.sh)**: Restores a logical backup.
  - Usage: `./restore_logical.sh <galera|repli> <filename.sql.gz>`

### Physical Backup (MariaBackup)

- **[backup_physical.sh](../scripts/backup_physical.sh)**: Creates a hot physical backup with MariaBackup.
  - Usage: `./backup_physical.sh <galera|repli>`
  - Features: Creates a consistent snapshot without locking the database.
- **[restore_physical.sh](../scripts/restore_physical.sh)**: Restores a physical backup.
  - Usage: `./restore_physical.sh <galera|repli> <filename.tar.gz>`
  - Works for both Galera and Replication clusters.
  - **CAUTION**: Back up required databases before you run `restore_physical.sh`. This script stops MariaDB and replaces the full data directory.

## 🔐 Security & SSL

- **[gen_ssl.sh](../scripts/gen_ssl.sh)**: Generates a complete SSL certificate chain (CA, Server, and Client).
  - Outputs are stored in the `ssl/` directory.
  - Containers mount certificates as read-only volumes.
- **[gen_pki.sh](../scripts/gen_pki.sh)**: Unified PKI & SAN X.509 certificate generator for all database topologies.
  - **Usage**: `bash ./scripts/gen_pki.sh [--dir PATH] [--cn NAME] [--san SAN_LIST] [--mode MODE] [--combine FILE] [--chown UID:GID] [--force]`
  - **Options**: `--dir` (output dir), `--cn` (Common Name), `--san` (SAN list), `--mode` (`mariadb|single|standard`), `--combine` (bundled PEM), `--chown` (`uid:gid`), `--force`. Enforces `0600` keys and `0644` certs.
- **Topology SSL Scripts**: `gen_ssl_innodb.sh` (InnoDB), `gen_ssl_pgpool.sh` (PgPool-II), `gen_ssl_mongo.sh` (MongoDB), `scripts/patroni/generate_certs.sh` (Patroni).

## ⚙️ Configuration & Setup

- **[setup_repli.sh](../scripts/setup_repli.sh)**: Automates Master/Slave replication setup.
  - Runs initial data sync from Master to Slaves.
  - Configures GTID-based replication.
- **[gen_profiles.sh](../scripts/gen_profiles.sh)**: Generates `profile_galera` and `profile_repli`.
  - Provides shell aliases (for example, `mariadb-m1` and `mariadb-g1`) for container access.
- **[start_mariadb.sh](../scripts/start_mariadb.sh)**: Custom entrypoint script for MariaDB Docker containers.
  - Runs database initialization (`mariadb-install-db`).
  - Executes scripts in `/docker-entrypoint-initdb.d/`.
  - Controls Galera bootstrap with the `MARIADB_GALERA_BOOTSTRAP` variable.

## 🧪 Testing

- **[interactive_runner.py](../interactive_runner.py)**: Legacy Python interactive test runner (prefer `./mdb interactive`). Preserves `-i`, `-a`, `-l en|fr`, skips MySQL-only `inject` on PostgreSQL, runs `make info`, and uses a localized retry prompt.
  - **Usage**: `./mdb interactive [-i|--interactive] [-a|--auto] [-l en|fr]` (legacy fallback: `python3 interactive_runner.py`)
- **[test_galera.sh](../tests/test_galera.sh)**: Full suite for Galera (sync, DDL, conflicts, Audit, SSL).
- **[test_repli.sh](../tests/test_repli.sh)**: Verification for Master/Slave replication.
- **[test_config.sh](../tests/test_config.sh)**: Central validation script that triggers `test_env.sh`, `test_security_ssl.sh`, and `test_profiles.sh`.
- **[test_haproxy_galera.sh](../tests/test_haproxy_galera.sh)**: Advanced validation suite for HAProxy.
  - Features: Latency benchmarking (LB vs Direct), persistence detection (Sticky/RR), real failover simulation, and HTML report generation.
  - Usage: `./test_haproxy_galera.sh`
- **[test_lb_galera.sh](../tests/test_lb_galera.sh)**: Lightweight load balancing distribution test.
  - Features: Connection distribution analysis, SSL verification, and sleek HTML report.
  - Usage: `./test_lb_galera.sh`
- **[test_perf_galera.sh](../tests/test_perf_galera.sh)** / **[test_perf_repli.sh](../tests/test_perf_repli.sh)**: Sysbench performance benchmarks.
- **[aggregate_reports.sh](../scripts/aggregate_reports.sh)**: Consolidates test reports into an executive HTML summary (`make test-all-report`).
  - Outputs: `reports/test_all_aggregated_<timestamp>.html` and `reports/latest_aggregated_report.html`.

## 🔍 Database Performance & Tuning Audit

- **[run_mysqltuner.sh](../scripts/run_mysqltuner.sh)**: Automated MySQLTuner auditing script supporting all MySQL/MariaDB topologies.
  - **Usage**: `bash ./scripts/run_mysqltuner.sh [--topology NAME] [--port PORT] [EXTRA_ARGS...]`
  - **Options**: `--topology, -t` (target cluster), `--port, -p` (port). Env: `MYSQLTUNER_PATH`, `DB_ROOT_PASSWORD`. Output: `reports/mysqltuner_<topo>_<ts>.txt`.

## 🚀 Unified `./mdb` (`mdb.cmd`) Go CLI Orchestrator

Single unified entry point (`./mdb` on Linux/macOS, `mdb.cmd` on Windows, pure-Go `cmd/mdb` / `bin/mdb` with zero external dependencies):
- `mdb help` / `mdb version` / `mdb doctor`: Show usage, synced `VERSION`, or diagnose Docker/Compose/Go/OpenSSL/Bash/`.env`/`ssl/`.
- `mdb catalog [--category ...] [--engine ...] [--eol] [--all] [--json]`: Query 31 active environments (11 standalone + 20 clusters) and 5 EOL entries (`aliases`: `list`, `envs`, `environments`, `topologies`).
- `mdb up <env>` / `mdb start [env]` / `mdb setup <env>` / `mdb down [env|all]` / `mdb stop`: Deploy standalone profiles or clusters (auto-PKI, EOL guard), run setup scripts, or tear down active stacks.
- `mdb status [env|all]` / `mdb info` / `mdb logs [env|svc]`: Inspect containers and tail/stream logs across standalone and cluster compose files.
- `mdb client [env]` / `mdb mycnf` / `mdb interactive [-a|-i] [-l en|fr]`: Open engine-aware DB shells, back up/write `0600` `~/.my.cnf`, or launch the native bilingual catalog wizard.
- `mdb lint` / `mdb test <env> [--suite]` / `mdb bench <env>`: Lint `.sh` + 21 compose stacks, verify health (or run `tests/test_<env>.sh`), and dispatch Sysbench/PG/Mongo benchmarks.
- `mdb pki <generate|verify> [topo] [--dir <dir>]` / `mdb report` / `mdb config`: Native x509 PKI, HTML/JSON telemetry reports, and JSON config dump.

## 📦 Release Automation

- **[release_notes.py](../scripts/release_notes.py)**: Stdlib release validator and `Changelog` note extractor. Workflow [`.github/workflows/release.yml`](../.github/workflows/release.yml) calls it to check `VERSION`, `Changelog`, and tag alignment.
