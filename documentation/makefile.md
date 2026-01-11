# Makefile Reference 🛠️

The `Makefile` is the main entry point for managing both Galera and Replication clusters.

## 🛠️ Global Commands

| Command | Description |
| :--- | :--- |
| `make help` | Show help message for all available tasks. |
| `make build-image` | Build the base `mariadb_ssh:004` image. |
| `make install-client` | Install MariaDB client on the host (Ubuntu/Debian). |
| `make gen-ssl` | Generate SSL certificates in `ssl/` directory. |
| `make renew-ssl-galera` | **Zero-downtime rotation** Galera: Regenerate and reload SSL via `FLUSH SSL`. |
| `make renew-ssl-repli` | **Zero-downtime rotation** Replication: Regenerate and reload SSL via `FLUSH SSL`. |
| `make clean-ssl` | Remove generated certificates. |
| `make clean-reports` | Purge all test reports (`.md` and `.html`) from the `reports/` directory. |
| `make gen-profiles` | Generate shell profiles for quick container access. |
| `make clean-galera` | Stop Galera and remove all its data/backups. |
| `make clean-repli` | Stop Replication and remove all its data/backups. |
| `make full-repli` | Full orchestration for Replication: Clean, Start, Setup, and Test. |
| `make full-galera` | Full orchestration for Galera: Clean, Start (Bootstrap), and Test. |
| `make clean-data` | **DANGER**: Remove ALL data, backup, and SSL directories. |

## 🌐 Galera Cluster Commands

| Command | Description |
| :--- | :--- |
| `make up-galera` | Start the Galera cluster nodes and HAProxy. |
| `make bootstrap-galera`| Sequentially bootstrap a new cluster (ensures node 1 is primary). |
| `make down-galera` | Stop and remove the Galera cluster. |
| `make logs-galera` | View real-time logs for the Galera cluster. |
| `make test-galera` | Run the advanced Galera test suite (Replication, DDL, Audit, SSL). |
| `make test-lb-galera` | Run the HAProxy validation suite (Performance, Failover, Reports). |
| `make backup-galera` | Perform a logical SQL backup. |
| `make backup-phys-galera`| Perform a physical (MariaBackup) backup. |
| `make restore-galera` | Restore a logical SQL backup. |
| `make restore-phys-galera`| Restore a physical (MariaBackup) backup. |
| `make test-perf-galera`| Run Sysbench benchmarks (Usage: `make test-perf-galera PROFILE=light ACTION=run`). |

## 💉 Data Injection

These commands automate the deployment of a clean Galera cluster followed by the injection of sample datasets.

| Command | Description |
| :--- | :--- |
| `make clone-test-db` | Clone or update the `test_db` repository from GitHub. |
| `make inject-employee-galera`| **Full Cycle**: Reset Galera and inject the `employees` database. |
| `make inject-sakila-galera`  | **Full Cycle**: Reset Galera and inject the `sakila` (MV) database. |
| `make inject-employee-repli` | **Full Cycle**: Reset Replication and inject `employees` database. |
| `make inject-sakila-repli`   | **Full Cycle**: Reset Replication and inject `sakila` database. |

## 🔄 Replication Cluster Commands

| Command | Description |
| :--- | :--- |
| `make up-repli` | Start the Replication cluster nodes and HAProxy. |
| `make setup-repli` | Configure Master/Slave relationship and initial sync. |
| `make down-repli` | Stop and remove the Replication cluster. |
| `make logs-repli` | View real-time logs for the Replication cluster. |
| `make test-repli` | Run the Replication functional test suite. |
| `make backup-repli` | Perform a logical SQL backup (on a slave). |
| `make backup-phys-repli`| Perform a physical (MariaBackup) backup. |
| `make restore-repli` | Restore a logical SQL backup. |
| `make restore-phys-repli`| Restore a physical (MariaBackup) backup. |
| `make test-perf-repli` | Run Sysbench benchmarks (Usage: `make test-perf-repli PROFILE=light ACTION=run`). |

## 🔍 Troubleshooting & Logs

These commands allow targeted access to logs within nodes without using `docker compose logs`.

| Command | Description |
| :--- | :--- |
| `make logs-error-galera` | View last 100 lines of MariaDB error log on a Galera node. |
| `make follow-error-galera`| Follow (tail -f) the MariaDB error log on a Galera node. |
| `make logs-slow-galera` | View last 100 lines of MariaDB slow query log on a Galera node. |
| `make follow-slow-galera` | Follow (tail -f) the slow query log on a Galera node. |
| `make logs-error-repli` | View last 100 lines of MariaDB error log on a Replication node. |
| `make follow-error-repli` | Follow (tail -f) the error log on a Replication node. |
| `make logs-slow-repli` | View last 100 lines of MariaDB slow query log on a Replication node. |
| `make follow-slow-repli` | Follow (tail -f) the slow query log on a Replication node. |

> **Pro Tip**: Use `NODE=2` or `NODE=3` (e.g., `make logs-error-galera NODE=2`) to target a specific node. Default is Node 1.
