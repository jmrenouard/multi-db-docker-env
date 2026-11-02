# Patroni PostgreSQL Cluster (RHEL 8)

This project includes a high-availability PostgreSQL 17 cluster based on RHEL 8 (UBI) images, orchestrating using Patroni and ETCD.

## Architecture

```mermaid
graph TD
    Client_W[Write Client] -->|Port 5000| LB[HAProxy LB<br/>Stats: 7000]
    Client_R[Read Client] -->|Port 5001| LB
    
    subgraph Patroni_PostgreSQL_Cluster [Patroni PG Cluster]
        LB -->|Writes (Leader)| N1["node1 (Leader)<br/>PostgreSQL"]
        LB -->|Read RR (Replicas)| N2["node2 (Replica)<br/>PostgreSQL"]
        LB -->|Read RR (Replicas)| N3["node3 (Replica)<br/>PostgreSQL"]
        
        N1 --"Streaming Replication"--> N2
        N1 --"Streaming Replication"--> N3
    end
    
    subgraph ETCD_Consensus [ETCD Consensus Cluster]
        E1[etcd1] <--> E2[etcd2]
        E2 <--> E3[etcd3]
        E3 <--> E1
    end
    
    N1 -.->|Consensus / DCS| ETCD_Consensus
    N2 -.->|Consensus / DCS| ETCD_Consensus
    N3 -.->|Consensus / DCS| ETCD_Consensus
```

- **ETCD Cluster**: 3 nodes (`etcd1`, `etcd2`, `etcd3`) for distributed configuration and consensus.
- **PostgreSQL Nodes**: 3 nodes (`node1`, `node2`, `node3`) managed by Patroni.
- **HAProxy**: Load balancer providing a single entry point for read-write and read-only traffic.

## Quick Start (or use `mdb up patroni` / `mdb status patroni`)

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
| PgBouncer | `6432` | Client connection pooling on PostgreSQL nodes. |
| Stats | `7000` | HAProxy statistics dashboard. |
| Patroni REST API | `8008` | Internal health check, config, and DCS election endpoint. |
| etcd | `2379` | Distributed consensus store client endpoint (`etcd1`). |

### Authenticated Connection Examples

```bash
export PGPASSWORD="${DB_ROOT_PASSWORD:-postgres}"
psql -h 127.0.0.1 -p 5000 -U postgres -d postgres  # Primary RW (HAProxy)
psql -h 127.0.0.1 -p 5001 -U postgres -d postgres  # Standby RO (HAProxy)
psql -h 127.0.0.1 -p 6432 -U postgres -d postgres  # PgBouncer pooler
curl -s http://127.0.0.1:7000/                     # HAProxy Stats
docker exec node1 curl -s http://localhost:8008/cluster # Patroni REST API
```

## Automated Testing

A functional test suite validates cluster health, consensus, replication, and failover across **8 test groups** (11 assertions in `tests/test_patroni.sh`).

### Run Tests

```bash
make patroni-test          # (or: make test-patroni / mdb test patroni)
```

### 8 Test Groups Breakdown

1. **ETCD Cluster Health**: Consensus quorum and DCS health across etcd nodes.
2. **Patroni REST API**: REST API endpoints (`:8008`) and DCS leader status query.
3. **PostgreSQL Topology & Replication**: Leader election and streaming replication to standbys.
4. **HAProxy Routing**: RW port 5000 leader routing and RO port 5001 replica balancing.
5. **PgBouncer Connection Pooling**: Client connection pooling through port 6432.
6. **Automatic Failover Simulation**: Leader stepdown/promotion and dynamic HAProxy routing updates.
7. **Configuration Audit**: `patronictl show-config`, node parameter parity, and TLS certificates.
8. **Sysbench Performance**: Transactional benchmark under concurrent OLTP workloads.

## Cleanup

```bash
make patroni-down          # (or: mdb down patroni)
```
