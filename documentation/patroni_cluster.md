# Patroni PostgreSQL HA Cluster

Deploy a **self-contained**, high-availability PostgreSQL 17 cluster with Patroni 4.x, etcd 3.5.17, and HAProxy LTS. In-repo non-root Dockerfiles (`scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}`) and secret-free `conf/patroni.yml` require zero external images. Legacy `patroni-rhel8-*:latest` tags remain compatible with Compose for **31/31** E2E coverage. See [architecture.md](architecture.md) for proxy design details.

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
- **HAProxy**: Single entry point load balancer for read-write and read-only traffic.

## Self-Contained Docker Images

| Image Tag | Dockerfile (Context `.`) | Pinned Base | Non-Root User |
| :--- | :--- | :--- | :--- |
| `patroni-rhel8-etcd:latest` | `scripts/patroni/Dockerfile.etcd` | `quay.io/coreos/etcd:v3.5.17` + `debian:bookworm-slim` | `etcd` |
| `patroni-rhel8-postgresql:latest` | `scripts/patroni/Dockerfile.postgresql` | `postgres:17-bookworm` + PGDG `patroni` + `supervisor` | `postgres` |
| `patroni-rhel8-haproxy:latest` | `scripts/patroni/Dockerfile.haproxy` | `haproxy:lts` + `conf/haproxy-patroni.cfg` | `haproxy` |

`./mdb up patroni` auto-builds any missing Patroni image and auto-generates `certs_patroni/` PKI. To build explicitly:

```bash
./mdb images build patroni       # or: make build-images TARGET=patroni
./mdb images check               # verifies 31/31 E2E images locally
```

## Quick Start

```bash
./mdb up patroni                 # Auto-builds images, generates mTLS certs, starts 7 containers (or: make patroni-up)
./mdb status patroni             # Check all 7 containers (etcd1..3, node1..3, haproxy-patroni)
./mdb client patroni             # Connect with psql to Primary RW (port 5000)
```

> Legacy wrappers `make patroni-gen-certs`, `make patroni-up`, and `make patroni-status` remain supported.

## Connection Details

| Role | Port | Description |
| :--- | :--- | :--- |
| Read-Write | `5000` | Traffic routed to the current Leader/Primary node through HAProxy. |
| Read-Only | `5001` | Traffic balanced across all healthy Replicas through HAProxy. |
| Stats (HTTPS) | `7000` | HAProxy HTTPS stats dashboard (`admin:adminpass`, self-signed TLS). |
| Patroni REST API | `8008` | Internal mTLS health check, config, and DCS election endpoint (`verify required`). |
| etcd | `2379` | Distributed consensus store mTLS client endpoint (`etcd1`). |

### Authenticated Connection Examples

```bash
export PGPASSWORD="${DB_ROOT_PASSWORD:-rootpass}"
psql -h 127.0.0.1 -p 5000 -U postgres -d postgres  # Primary RW (HAProxy)
psql -h 127.0.0.1 -p 5001 -U postgres -d postgres  # Standby RO (HAProxy)
curl -sk -u admin:adminpass https://127.0.0.1:7000/ # HAProxy HTTPS Stats
docker exec node1 patronictl -c /etc/patroni.yml list
docker exec node1 curl -fsS --cacert /etc/patroni/certs/ca.crt --cert /etc/patroni/certs/patroni-api.crt --key /etc/patroni/certs/patroni-api.key https://localhost:8008/cluster
```

## Automated Testing

Run `./mdb test patroni` for the native Go verifier (`3/3` active: 1 Leader/Primary and 2 replicas). Run `./mdb test patroni --suite` for **11 test groups** (`14` assertions in `tests/test_patroni.sh`). Run `bash ./tests/test_failover.sh patroni` to validate automatic leader failover (`1/1`).

```bash
./mdb test patroni               # Go health verifier (HEALTHY 3/3)
./mdb test patroni --suite       # Full 14-assertion suite (or: make patroni-test / make test-patroni)
bash ./tests/test_failover.sh patroni # Live leader failover & timeline rejoin
```

### 11 Test Groups (`tests/test_patroni.sh`)

1. **Cluster Status**: Patroni Leader/Primary election and `>= 2` healthy replicas (`patronictl list`).
2. **HAProxy Connectivity**: RW (`5000`) and RO (`5001`) routing with Docker DNS `resolvers docker` and mTLS checks.
3. **Write Replication**: Primary write propagation to standbys.
4. **Write Isolation**: RO port (`5001`) rejects writes (`pg_is_in_recovery()`).
5. **DDL Replication**: Schema creation replicated across nodes.
6. **CRUD Operations**: `INSERT`/`UPDATE`/`DELETE` round-trip consistency.
7. **Version Consistency**: Uniform PostgreSQL `17.x` version across nodes.
8. **Config Consistency**: Parameter parity (`max_connections`, `shared_buffers`, `wal_level`).
9. **HAProxy HTTPS Stats**: Authenticated `https://127.0.0.1:7000/` endpoint availability.
10. **Concurrent Writes**: 30/30 parallel write integrity check.
11. **TLS/SSL Verification**: Active `ssl=on` and negotiated TLS cipher across connections.

## Cleanup

```bash
./mdb down patroni               # Stops containers and removes volumes (or: make patroni-down)
```
