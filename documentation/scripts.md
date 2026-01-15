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

## ⚙️ Configuration & Setup

- **[setup_repli.sh](../scripts/setup_repli.sh)**: Automates the Master/Slave replication setup.
  - Performs initial data sync from Master to Slaves.
  - Sets up GTID-based replication.
- **[gen_profiles.sh](../scripts/gen_profiles.sh)**: Generates `profile_galera` and `profile_repli`.
  - Provides shell aliases (e.g., `mariadb-m1`, `mariadb-g1`) for quick access to containers.
- **[start-mariadb.sh](../scripts/start-mariadb.sh)**: Custom entrypoint script for the MariaDB Docker containers.
  - Handles database initialization (`mariadb-install-db`).
  - Executes scripts in `/docker-entrypoint-initdb.d/`.
  - Manages Galera bootstrapping via `MARIADB_GALERA_BOOTSTRAP` environment variable.

## 🧪 Testing

- **[test_galera.sh](../tests/test_galera.sh)**: Full suite for Galera (sync, DDL, conflicts, Audit, SSL).
- **[test_repli.sh](../tests/test_repli.sh)**: Verification for Master/Slave replication.
- **[test_haproxy_galera.sh](../tests/test_haproxy_galera.sh)**: Advanced validation suite for HAProxy.
  - Features: Latency benchmarking (LB vs Direct), persistence detection (Sticky/RR), real failover simulation, and HTML report generation.
  - Usage: `./test_haproxy_galera.sh`
- **[test_lb_galera.sh](../tests/test_lb_galera.sh)**: Lightweight load balancing distribution test.
  - Features: Connection distribution analysis, SSL verification, and sleek HTML report.
  - Usage: `./test_lb_galera.sh`
- **[test_perf_galera.sh](../tests/test_perf_galera.sh)** / **[test_perf_repli.sh](../tests/test_perf_repli.sh)**: Performance benchmarks using Sysbench.
