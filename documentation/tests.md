# Test Cases & Results 🧪

This document describes the automated test suites available to validate the clusters.

## 📊 Test Reports

All report files (Galera, Replication, Performance Sysbench, and HAProxy) are centralized in the `reports/` directory:

- **Markdown (.md)**: For quick CLI review or documentation integration.
- **HTML (.html)**: Premium interactive reports (Tailwind CSS, Chart.js).

Filenames follow the pattern: `test_<type>_<timestamp>.[md|html]`.

---

## 🏗️ Architecture Information

For more details on the cluster topology, refer to the **[Architecture Documentation](architecture.md)**.

---

## 00. Standalone Matrix (T2 tier)

| MySQL | MariaDB | Percona | PostgreSQL |
| :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="25" height="25"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="25" height="25"> | <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/percona.svg" alt="Percona" width="25" height="25"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="25" height="25"> |

Verified on **2026-01-29**, this suite validates all standalone database engines.

### Test Cases

1. **Service Lifecycle**: Starts each DB service (MySQL, MariaDB, Percona, PostgreSQL) and checks process health.
2. **Data Integrity**: Injects `employees` and `sakila` sample databases.
3. **Authentication Audit**: Checks that `DB_ROOT_PASSWORD` applies across all versions.
4. **Connectivity**: Checks Traefik routing to the active instance on port `3306` (MySQL/MariaDB) or `5432` (PostgreSQL).

## ⚙️ 0. Configuration & Security (`make test-config`)

This suite checks environment integrity before you start any containers.

### Test Cases

1. **Environment Consistency**: Checks that `.env` exists and defines required passwords (for example, `DB_ROOT_PASSWORD`).
2. **Directory Structure**: Checks key directories (`scripts/`, `conf/`, `tests/`, `documentation/`).
3. **Docker Compose Validation**: Runs `docker compose config` on all Compose files to prevent syntax errors.
4. **Configuration Inventory**: Checks all `.cnf`, `.cfg`, and `.sql` files in `conf/`.
5. **Script Permissions**: Audits `scripts/` and `tests/` for execution permissions.
6. **SSL Security Audit**:
   - Checks that the local CA signs the SSL certificate chain.
   - Checks certificate expiry dates.
   - **Key Consistency**: Checks that `server-key.pem` matches `server-cert.pem`.
7. **Profile Integrity**: Checks that `profile_galera` and `profile_repli` define valid shell aliases.

## 🌐 1. Galera Test Suite (`test_galera.sh`)

### Test Cases

1. **Connectivity & Status**: Checks that all 3 nodes are UP, `wsrep_ready=ON`, and cluster size equals 3.
2. **Synchronous Replication**:
   - Write on Node 1 -> Read on Node 2 and Node 3.
   - Write on Node 3 -> Read on Node 1.
3. **Auto-increment Consistency**: Checks that each node uses a unique offset to avoid ID collisions.
4. **Certification Conflict (Optimistic Locking)**: Simulates concurrent updates on the same row across different nodes to trigger a certification failure.
5. **DDL Replication**: Runs `ALTER TABLE` on one node and checks schema changes on other nodes.
6. **Unique Key Constraint**: Checks that duplicate entry errors propagate across nodes.
7. **Configuration Verification**: Validates that **Performance Schema** and **Slow Query Log** are active.
8. **Galera Provider Audit**: Compares current `wsrep_provider_options` against best practices.
9. **SSL Expiry**: Checks if certificates expire in less than 30 days.

### Typical Results

```text
✅ Node at port 3511 is UP (Ready: ON, Cluster Size: 3, State: Synced, SSL: TLS_AES_128_GCM_SHA256, GTID: 1)
✅ Node 2 received data correctly
✅ Node 1: Column 'new_col' exists
✅ Node 2 correctly rejected duplicate entry
```

---

## 🔄 2. Replication Test Suite (`test_repli.sh`)

### Test Cases

1. **Connectivity & SSL**: Checks if Master and both Slaves are reachable and reports SSL status.
2. **Topology Verification**: Displays `SHOW MASTER STATUS` and `SHOW SLAVE STATUS` (IO/SQL threads).
3. **Data Replication**:
   - Create DB/Table on Master.
   - Write sample data on Master.
   - Verify data presence on Slave 1 and Slave 2 after a short delay.

### Typical Results

```text
✅ Port 3411 is UP (SSL: TLS_AES_128_GCM_SHA256)
✅ Slave 1 received: Hello from Master at Mon Jan  5 08:30:00 UTC 2026
```

---

## 🏎️ 3. Performance Tests (Sysbench)

Run `test_perf_galera.sh` or `test_perf_repli.sh`.

- **Output**: Generates an interactive HTML report (for example, `test_perf_galera.html`).
- **Metrics**: TPS (Transactions Per Second), Latency (95th percentile), and Error rates.

---

## 🔵 4. HAProxy Validation (`test_haproxy_galera.sh`)

### Test Cases

1. **Backend Health**: Checks the UP/DOWN state of each MariaDB node with the HAProxy Stats API.
2. **Latency Benchmark**: Compares average query latency between the Load Balancer and direct node access.
3. **Persistence Detection**: Checks whether HAProxy uses Round-Robin or Sticky sessions.
4. **Failover Simulation**:
   - Stops one MariaDB container (`docker stop`).
   - Checks SQL query continuity during the outage.
   - Restarts the stopped node automatically.

### Premium Reports

This suite also generates an HTML report with latency overhead and failover metrics.
