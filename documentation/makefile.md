# Makefile Reference 🛠️

The `Makefile` is the main entry point for managing database environments (Standalone, Galera, and Replication).

## 🛠️ Global Commands

| Command | Description |
| :--- | :--- |
| `make stop` | 🛑 Stop and remove all containers and networks. |
| `make status` | 📊 Display the status of active containers. |
| `make info` | ℹ️ Provide information about the active DB service. |
| `make logs` | 📄 Display logs for the active database service. |
| `make mycnf` | 🔑 Generate the `.my.cnf` file for password-less connections. |
| `make client` | 💻 Start a MySQL client on the active database. |
| `make verify` | ✅ Runs complete environment validation (`test-config`). |
| `make start` | 🚀 Starts the default service (`mariadb114`). |
| `make help` | Show help message for all available tasks. |
| `make build-go` | 🔨 Compile native Go `mdb` binary into `bin/mdb`. |
| `make test-go` | 🧪 Run complete Go unit test suite (`go test -v ./...`). |
| `make test-all-topologies` | 🧪 Run E2E tests across all standalone DBs and HA topologies. |
| `make test-all-report` | 📊 Aggregate individual test reports into consolidated HTML report. |
| `make test-failover` | 🧪 Run primary failover & resilience verification tests. |
| `make test-backup-restore` | 🧪 Run backup and restore verification tests. |
| `make gen-ssl-all` | 🔐 Generate TLS certificates for all HA topologies. |
| `make check-ssl-all` | 🔍 Verify TLS certificate validity for all topologies. |
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
| `make check-galera` | 📊 Check Galera cluster status (WSREP, Buffer Pool, etc.). |
| `make check-repli` | 📊 Check Replication status (Slave Status, Read Only, etc.). |
| `make test-config` | 🧪 Validate orchestration configuration, SSL, and profiles. |
| `make full-repli` | Full orchestration for Replication: Clean, Start, Setup, and Test. |
| `make full-galera` | Full orchestration for Galera: Clean, Start (Bootstrap), and Test. |
| `make clean-data` | **DANGER**: Remove ALL data, backup, and SSL directories. |
| `make inject` | 💉 Alias for `inject-employees` with auto-detection. |
| `make inject-employees` | 💉 Inject `employees` database with auto-detection. |
| `make inject-sakila` | 💉 Inject `sakila` database with auto-detection. |
| `make sync-test-db` | 🔄 Synchronize the `test_db` submodule. |

## 🐬 Standalone Database Commands

| Command | Description |
| :--- | :--- |
| `make mysql96` | Starts MySQL 9.6 |
| `make mysql84` | Starts MySQL 8.4 |
| `make mysql80` | Starts MySQL 8.0 |
| `make mysql57` | Starts MySQL 5.7 |
| `make mariadb118` | Starts MariaDB 11.8 |
| `make mariadb114` | Starts MariaDB 11.4 |
| `make mariadb1011`| Starts MariaDB 10.11 |
| `make mariadb106` | Starts MariaDB 10.6 |
| `make percona80` | Starts Percona Server 8.0 |
| `make postgres17` | Starts PostgreSQL 17 |
| `make postgres16` | Starts PostgreSQL 16 |
| `make postgres15` | Starts PostgreSQL 15 |

## 🌐 Galera Cluster Commands

| Command | Description |
| :--- | :--- |
| `make up-galera` | Start the Galera cluster nodes and HAProxy. |
| `make bootstrap-galera`| Sequentially bootstrap a new cluster (ensures node 1 is primary). |
| `make emergency-galera`| Emergency start of a single Galera node (Usage: `make emergency-galera NODE=1`). |
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
| `make inject-data` | 💉 Inject a sample database (`employees` or `sakila`) into a single-instance service. |
| `make test-all` | 🧪 Run full test suite across multiple DB versions. |
| `make sync-test-db` | 🔄 Synchronize the `test_db` submodule from remote master. |
| `make inject-employee-galera`| **Full Cycle**: Reset Galera and inject the `employees` database. |
| `make inject-sakila-galera`  | **Full Cycle**: Reset Galera and inject the `sakila` (MV) database. |
| `make inject-employee-repli` | **Full Cycle**: Reset Replication and inject `employees` database. |
| `make inject-sakila-repli`   | **Full Cycle**: Reset Replication and inject `sakila` database. |

## 🔄 Replication Cluster Commands

| Command | Description |
| :--- | :--- |
| `make up-repli` | Start the Replication cluster nodes and HAProxy. |
| `make setup-repli` | Configure Master/Slave relationship and initial sync. |
| `make emergency-repli`| Emergency start of a single Replication node (Usage: `make emergency-repli NODE=1`). |
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

## 🐘 Patroni PostgreSQL HA Cluster Commands

| Command | Description |
| :--- | :--- |
| `make patroni-up` | Start 3-node PostgreSQL 17 + ETCD + HAProxy cluster. |
| `make patroni-down` | Stop Patroni cluster and remove volumes. |
| `make patroni-status` | Display Patroni node status via `patronictl`. |
| `make patroni-logs` | Follow real-time logs for Patroni cluster. |
| `make patroni-ps` | List running Patroni containers. |
| `make test-patroni` | Run Patroni functional test suite. |

## 🐘 PgPool-II Cluster Commands

| Command | Description |
| :--- | :--- |
| `make pgpool-up` | Start PostgreSQL 17 + PgPool-II load balancer cluster. |
| `make pgpool-down` | Stop PgPool-II cluster and remove volumes. |
| `make pgpool-status` | Show PgPool-II node status via `SHOW pool_nodes`. |
| `make pgpool-logs` | Follow real-time logs for PgPool-II cluster. |
| `make pgpool-ps` | List running PgPool-II containers. |
| `make test-pgpool` | Run PgPool-II functional test suite. |

## 🐬 MySQL InnoDB Cluster Commands

| Command | Description |
| :--- | :--- |
| `make innodb-up` | Start MySQL 8.4 InnoDB Cluster (3 nodes + Router). |
| `make innodb-down` | Stop InnoDB Cluster and remove volumes. |
| `make innodb-status` | Display Group Replication members status. |
| `make innodb-logs` | Follow real-time logs for InnoDB Cluster. |
| `make innodb-ps` | List running InnoDB Cluster containers. |
| `make test-innodb` | Run InnoDB Cluster functional test suite. |

## 🍃 MongoDB ReplicaSet Commands

| Command | Description |
| :--- | :--- |
| `make mongo-up` | Start MongoDB 7 ReplicaSet (3 nodes + HAProxy). |
| `make mongo-down` | Stop MongoDB 7 ReplicaSet and remove volumes. |
| `make mongo-status` | Display ReplicaSet member health and status. |
| `make test-mongo` | Run MongoDB 7 functional test suite. |
| `make test-perf-mongo` | Run performance benchmark on MongoDB ReplicaSet. |
| `make mongo8-up` | Start MongoDB 8 ReplicaSet (3 nodes + HAProxy). |
| `make mongo8-down` | Stop MongoDB 8 ReplicaSet and remove volumes. |
| `make mongo8-status` | Display MongoDB 8 ReplicaSet member status. |
| `make test-mongo8` | Run MongoDB 8 functional test suite. |

## 🔍 MySQLTuner Integration Commands

| Command | Description |
| :--- | :--- |
| `make mysqltuner-galera` | Run MySQLTuner audit against Galera Cluster. |
| `make mysqltuner-innodb` | Run MySQLTuner audit against InnoDB Cluster. |
| `make mysqltuner-repli` | Run MySQLTuner audit against MariaDB Replication. |
| `make mysqltuner-all` | Run MySQLTuner audit across all HA topologies. |
