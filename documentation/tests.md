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

## 🌐 1. Galera Test Suite (`test_galera.sh`)

### Test Cases

1. **Connectivity & Status**: Verifies all 3 nodes are UP, `wsrep_ready=ON`, and cluster size is 3.
2. **Synchronous Replication**:
   - Write on Node 1 -> Read on Node 2 and Node 3.
   - Write on Node 3 -> Read on Node 1.
3. **Auto-increment Consistency**: Ensures each node uses a different offset to avoid ID collisions.
4. **Certification Conflict (Optimistic Locking)**: Simulates simultaneous updates on the same row across different nodes to trigger a deadlock/certification failure.
5. **DDL Replication**: Runs `ALTER TABLE` on one node and verifies schema changes on others.
6. **Unique Key Constraint**: Verifies that duplicate entry errors are correctly propagated and handled.
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

Executed via `test_perf_galera.sh` or `test_perf_repli.sh`.

- **Output**: Generates a high-quality HTML report (e.g., `test_perf_galera.html`).
- **Metrics**: TPS (Transactions Per Second), Latency (95th percentile), and Error rates.

---

## 🔵 4. HAProxy Validation (`test_haproxy_galera.sh`)

### Test Cases

1. **Backend Health**: Verifies the state (UP/DOWN) of each MariaDB node via HAProxy's Stats API.
2. **Latency Benchmark**: Compares the average query latency through the Load Balancer vs direct node connection.
3. **Persistence Detection**: Identifies if HAProxy is configured with Round-Robin or Sticky sessions.
4. **Failover Simulation**:
   - Real-world shutdown of a MariaDB container (`docker stop`).
   - Verifies SQL query continuity during the outage.
   - Automatic node restart.

### Premium Reports

Like other tests, this suite generates an elegant HTML report showing performance overhead and failover statistics.
