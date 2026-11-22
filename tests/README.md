# Test Suites Documentation 🧪

This directory contains automated test suites to validate all supported database engines and topologies.

## 📁 Test Categories

### 1. Configuration & Health Check

- **[test_config.sh](./test_config.sh)**: Validates directory structure, Docker Compose syntax, and file existence.
- **[test_env.sh](./test_env.sh)**: Ensures `.env` is present and contains required variables.
- **[test_security_ssl.sh](./test_security_ssl.sh)**: Verifies SSL certificate chaining, expiry, and key consistency.
- **[test_profiles.sh](./test_profiles.sh)**: Validates shell profile generation and alias consistency.

### 2. Functional Cluster & Multi-Engine Suites

- **[test_galera.sh](./test_galera.sh)** / **[test_repli.sh](./test_repli.sh)**: MariaDB Galera and Master/Slave replication suites.
- **[test_innodb_cluster.sh](./test_innodb_cluster.sh)** / **[test_mongo_rs.sh](./test_mongo_rs.sh)**: MySQL 8.4 InnoDB Cluster and MongoDB 7.0/8.0 ReplicaSet suites.
- **[test_patroni.sh](./test_patroni.sh)** / **[test_pgpool.sh](./test_pgpool.sh)**: PostgreSQL Patroni HA and PgPool-II suites.
- **PostgreSQL 17/18 & Distributed SQL**: `test_pg_*.sh`, `test_pg18_*.sh`, `test_pgedge.sh`, `test_bucardo.sh`, `test_citus.sh`, `test_cockroach.sh`, `test_yugabyte.sh`, and `test_yt_cluster.sh`.
- **Python Unit & Static Tests**: `test_lab.py`, `test_pg_libs.py`, `test_project_governance_rules.py`, `test_python_audit_fixes.py`, `test_python_runners.py`, `test_release_workflow.py`, and `test_repo_static.py`.

### 3. Load Balancing & HA

- **[test_haproxy_galera.sh](./test_haproxy_galera.sh)**: Advanced HAProxy validation (Latency, Failover, Sticky sessions).
- **[test_lb_galera.sh](./test_lb_galera.sh)**: Lightweight load distribution analysis.

### 4. Performance Benchmarking

- **[test_perf_galera.sh](./test_perf_galera.sh)**: Sysbench patterns specialized for Galera clusters.
- **[test_perf_repli.sh](./test_perf_repli.sh)**: Sysbench patterns specialized for Replication clusters.
- **[test_perf_mongo.sh](./test_perf_mongo.sh)**: Performance benchmark suite for MongoDB ReplicaSet.

## 🚀 Running Tests

### Root & Unit Tests (Fast)

```bash
python -m unittest discover -s tests -v
make test-config
./mdb lint
```

### Full Functional Clusters

```bash
./mdb test galera --suite
make test-galera
make test-repli
```

## 📊 Reports

Most scripts generate reports in the `reports/` directory in both Markdown and HTML formats.
