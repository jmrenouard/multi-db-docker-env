# Patroni PostgreSQL Cluster (RHEL 8)

This project includes a high-availability PostgreSQL 17 cluster based on RHEL 8 (UBI) images, orchestrating using Patroni and ETCD.

## Architecture

- **ETCD Cluster**: 3 nodes (`etcd1`, `etcd2`, `etcd3`) for distributed configuration and consensus.
- **PostgreSQL Nodes**: 3 nodes (`node1`, `node2`, `node3`) managed by Patroni.
- **HAProxy**: Load balancer providing a single entry point for read-write and read-only traffic.

## Quick Start

### 1. Generate Certificates

The cluster uses mutual TLS for communication between nodes and ETCD.

```bash
make patroni-gen-certs
```

### 2. Start the Cluster

```bash
make patroni-up
```

### 3. Check Status

```bash
make patroni-status
```

## Connection Details

| Role | Port | Description |
| :--- | :--- | :--- |
| Read-Write | `5000` | Traffic routed to the current Leader node. |
| Read-Only | `5001` | Traffic balanced across all healthy Replicas. |
| Stats | `7000` | HAProxy statistics dashboard. |

### Example connection

```bash
psql -h 127.0.0.1 -p 5000 -U postgres
```

## Automated Testing

A functional test suite is available to validate cluster health, replication, and HAProxy routing.

### Run Tests

Ensure the cluster is running, then execute:

```bash
make test-patroni
```

The test script will:
- Check overall cluster status (`patronictl list`).
- Verify Read-Write and Read-Only connectivity via HAProxy.
- Validate synchronous replication by creating test data on the Leader and verifying it on Replicas.

## Cleanup

```bash
make patroni-down
```
