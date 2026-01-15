# Test Suites Documentation 🧪

This directory contains various test suites to validate the MariaDB environment at different levels.

## 📁 Test Categories

### 1. Configuration & Health Check

- **[test_config.sh](./test_config.sh)**: Validates directory structure, Docker Compose syntax, and file existence.
- **[test_env.sh](./test_env.sh)**: Ensures `.env` is present and contains required variables.
- **[test_security_ssl.sh](./test_security_ssl.sh)**: Verifies SSL certificate chaining, expiry, and key consistency.
- **[test_profiles.sh](./test_profiles.sh)**: Validates shell profile generation and alias consistency.

### 2. Functional Cluster Tests

- **[test_galera.sh](./test_galera.sh)**: Full functional suite for Galera cluster (Sync, DDL, Conflicts, Audit).
- **[test_repli.sh](./test_repli.sh)**: Functional suite for Master/Slave replication.

### 3. Load Balancing & HA

- **[test_haproxy_galera.sh](./test_haproxy_galera.sh)**: Advanced HAProxy validation (Latency, Failover, Sticky sessions).
- **[test_lb_galera.sh](./test_lb_galera.sh)**: Lightweight load distribution analysis.

### 4. Performance Benchmarking

- **[test_perf_threads.sh](./test_perf_threads.sh)**: Benchmarks thread scaling impact on performance.
- **[test_perf_galera.sh](./test_perf_galera.sh)**: Sysbench patterns specialized for Galera clusters.
- **[test_perf_repli.sh](./test_perf_repli.sh)**: Sysbench patterns specialized for Replication clusters.

## 🚀 Running Tests

### Root Tests (Fast)

To run all configuration and security tests:

```bash
make test-config
```

### Full Functional Clusters (Slow)

To run full functional tests (requires clusters to be up):

```bash
make test-galera
# or
make test-repli
```

## 📊 Reports

Most scripts generate reports in the `reports/` directory in both Markdown and HTML formats.
