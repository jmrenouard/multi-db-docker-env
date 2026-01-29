# Integral Test Plan: Multi-DB Docker Environment

## 🧠 Rationale

The objective of this plan is to guarantee architectural reliability, functional consistency, and performance of all platforms and versions supported by the laboratory.

---

## 📅 Test Matrix

| DB System | Version | Standalone | Galera | Replication |
| :--- | :--- | :---: | :---: | :---: |
| **MariaDB** | 10.6 | ✅ (2026-01-29) | ❌ | ❌ |
| **MariaDB** | 10.11 | ✅ (2026-01-29) | ❌ | ❌ |
| **MariaDB** | 11.4 | ✅ (2026-01-29) | ❌ | ❌ |
| **MariaDB** | 11.8 (LTS) | ✅ (2026-01-29) | ✅ | ✅ |
| **MySQL** | 5.7 (Legacy) | ✅ (2026-01-29) | ❌ | ❌ |
| **MySQL** | 8.0 | ✅ (2026-01-29) | ❌ | ❌ |
| **MySQL** | 8.4 | ✅ (2026-01-29) | ❌ | ❌ |
| **MySQL** | 9.6 | ✅ (2026-01-29) | ❌ | ❌ |
| **Percona Server** | 8.0 | ✅ (2026-01-29) | ❌ | ❌ |

---

## 🛠️ Test Suites (Verification Levels)

### T1: Orchestration & Governance Audit

* **Command**: `make test-config`
* **Checks**: Directory structure, Docker Compose syntax, SSL certificate presence, Shell profile generation, metadata consistency.

### T2: Standalone Lifecycle & Data Integrity

* **Command**: `make test-all`
* **Workflow**:
    1. Container provisioning via Traefik.
    2. Data injection of `employees` and `sakila` sets.
    3. Row count and schema integrity check.
    4. Connectivity validation via Traefik reverse proxy (port 3306).
    5. Atomic cleanup.

### T3: Cluster Topology & Convergence

* **Commands**: `make test-galera`, `make test-repli`
* **Galera Specifics**:
  * Node synchronization (`Synced`).
  * Quorum validation (3-node cluster).
  * Global sequence consistency across nodes.
* **Replication Specifics**:
  * IO and SQL thread health (Master/Slave).
  * GTID consistency.
  * `read-only` enforcement on slaves for non-SUPER users.

### T4: High Availability & Load Balancing

* **Command**: `make test-lb-galera`
* **Workflow**:
    1. HAProxy distribution stress test (Round-Robin verification).
    2. Failure simulation: Node shutdown and service continuity verification.
    3. SSL termination check at the proxy level.

### T5: Performance Analysis (Sysbench)

* **Commands**: `make test-perf-galera`, `make test-perf-repli`
* **Profiles**: `light`, `standard`, `read-only`, `write-only`.
* **Metrics**: TPS (Transactions/sec), P95 Latency, Conflict deltas (WSREP Aborts for Galera).

---

## 🚀 Execution Strategy

### 1. Daily Smoke Test

```bash
make test-config
make mariadb118  # Prime LTS target
make inject
make info
make stop
```

### 2. Pre-Release Validation (Exhaustive)

```bash
# 1. Governance
make test-config

# 2. Standalone Matrix
make test-all

# 3. Clusters
make full-galera
make full-repli

# 4. Performance Baselines
make test-perf-galera PROFILE=standard ACTION=run
make test-perf-repli PROFILE=standard ACTION=run
```

---

## 📊 Reporting

All tests generate reports in the `reports/` directory:

* `reports/config_report.html` (T1)
* `reports/test_galera_*.html` (T3)
* `reports/test_repli_*.html` (T3)
* `reports/test_lb_galera_*.html` (T4)
* `reports/test_perf_*.html` (T5)
