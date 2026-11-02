# Utility Scripts Documentation 📜

This document describes the various shell scripts available in the root directory for managing the MariaDB environment.

## 💾 Backup & Restore

### Logical Backup (`mariadb-dump`)

- **[backup_logical.sh](../scripts/backup_logical.sh)**: Performs a compressed SQL dump.
  - Usage: `./backup_logical.sh <galera|repli> [database_name]`
  - Features: Uses `pigz` for fast compression, includes routines, triggers, and events.
- **[restore_logical.sh](../scripts/restore_logical.sh)**: Restores a logical backup.
  - Usage: `./restore_logical.sh <galera|repli> <filename.sql.gz>`

### Physical Backup (MariaBackup)

- **[backup_physical.sh](../scripts/backup_physical.sh)**: Performs a hot physical backup using MariaBackup.
  - Usage: `./backup_physical.sh <galera|repli>`
  - Features: Creates a consistent snapshot without locking the database.
- **[restore_physical.sh](../scripts/restore_physical.sh)**: Restores a physical backup.
  - Usage: `./restore_physical.sh <galera|repli> <filename.tar.gz>`
  - Works for both Galera and Replication clusters.
  - **CAUTION**: This script stops MariaDB, replaces the entire data directory, and restarts it.

## 🔐 Security & SSL

- **[gen_ssl.sh](../scripts/gen_ssl.sh)**: Generates a complete SSL certificate chain (CA, Server, and Client).
  - Outputs are stored in the `ssl/` directory.
  - Certificates are automatically used by containers via volume mounts.
- **[gen_pki.sh](../scripts/gen_pki.sh)**: Unified PKI & SAN X.509 certificate generator for all database topologies.
  - **Usage**: `bash ./scripts/gen_pki.sh [--dir PATH] [--cn NAME] [--san SAN_LIST] [--mode MODE] [--combine FILE] [--chown UID:GID] [--force]`
  - **Options**: `--dir` (output dir), `--cn` (Common Name), `--san` (SAN list), `--mode` (`mariadb|single|standard`), `--combine` (bundled PEM), `--chown` (`uid:gid`), `--force`. Enforces `0600` keys and `0644` certs.
- **Topology SSL Scripts**: `gen_ssl_innodb.sh` (InnoDB), `gen_ssl_pgpool.sh` (PgPool-II), `gen_ssl_mongo.sh` (MongoDB), `scripts/patroni/generate_certs.sh` (Patroni).

## ⚙️ Configuration & Setup

- **[setup_repli.sh](../scripts/setup_repli.sh)**: Automates the Master/Slave replication setup.
  - Performs initial data sync from Master to Slaves.
  - Sets up GTID-based replication.
- **[gen_profiles.sh](../scripts/gen_profiles.sh)**: Generates `profile_galera` and `profile_repli`.
  - Provides shell aliases (e.g., `mariadb-m1`, `mariadb-g1`) for quick access to containers.
- **[start_mariadb.sh](../scripts/start_mariadb.sh)**: Custom entrypoint script for the MariaDB Docker containers.
  - Handles database initialization (`mariadb-install-db`).
  - Executes scripts in `/docker-entrypoint-initdb.d/`.
  - Manages Galera bootstrapping via `MARIADB_GALERA_BOOTSTRAP` environment variable.

## 🧪 Testing

- **[interactive_runner.py](../interactive_runner.py)**: Interactive and automated test orchestration dashboard.
  - **Features**: Choice of installation type (Standalone, Galera, Replication), real-time progress, and beautiful auto-refreshing HTML report with Tailwind CSS.
  - **Usage**: `python3 interactive_runner.py [-i|--interactive] [-a|--auto]`
- **[test_galera.sh](../tests/test_galera.sh)**: Full suite for Galera (sync, DDL, conflicts, Audit, SSL).
- **[test_repli.sh](../tests/test_repli.sh)**: Verification for Master/Slave replication.
- **[test_config.sh](../tests/test_config.sh)**: Central validation script that triggers `test_env.sh`, `test_security_ssl.sh`, and `test_profiles.sh`.
- **[test_haproxy_galera.sh](../tests/test_haproxy_galera.sh)**: Advanced validation suite for HAProxy.
  - Features: Latency benchmarking (LB vs Direct), persistence detection (Sticky/RR), real failover simulation, and HTML report generation.
  - Usage: `./test_haproxy_galera.sh`
- **[test_lb_galera.sh](../tests/test_lb_galera.sh)**: Lightweight load balancing distribution test.
  - Features: Connection distribution analysis, SSL verification, and sleek HTML report.
  - Usage: `./test_lb_galera.sh`
- **[test_perf_galera.sh](../tests/test_perf_galera.sh)** / **[test_perf_repli.sh](../tests/test_perf_repli.sh)**: Performance benchmarks using Sysbench.
- **[aggregate_reports.sh](../scripts/aggregate_reports.sh)**: Consolidates test reports into an executive HTML summary (`make test-all-report`).
  - Outputs: `reports/test_all_aggregated_<timestamp>.html` and `reports/latest_aggregated_report.html`.

## 🔍 Database Performance & Tuning Audit

- **[run_mysqltuner.sh](../scripts/run_mysqltuner.sh)**: Automated MySQLTuner auditing script supporting all MySQL/MariaDB topologies.
  - **Usage**: `bash ./scripts/run_mysqltuner.sh [--topology NAME] [--port PORT] [EXTRA_ARGS...]`
  - **Options**: `--topology, -t` (target cluster), `--port, -p` (port). Env: `MYSQLTUNER_PATH`, `DB_ROOT_PASSWORD`. Output: `reports/mysqltuner_<topo>_<ts>.txt`.

## 🚀 Go `mdb` CLI Orchestrator

Compiled pure-Go CLI (`cmd/mdb`, `bin/mdb` with zero external dependencies):
- `mdb version`: Display binary version (`2.0.2`).
- `mdb config [-env <path>]`: Dump active environment settings as JSON.
- `mdb topologies`: List registered topologies.
- `mdb up <topo>` / `mdb down <topo>` / `mdb status <topo>`: Orchestrate database topologies.
- `mdb test <topo>`: Run cluster health verification assertions.
- `mdb bench <topo> [-workload <w>] [-threads <n>] [-duration <d>]`: Run Sysbench OLTP benchmarks.
- `mdb pki <generate|verify> [topo] [--dir <dir>]`: Generate or verify TLS/SSL certificates natively.
- `mdb report [topos...] [-json <path>] [-html <path>]`: Execute multi-cluster verification and export reports.
