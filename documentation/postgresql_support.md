# PostgreSQL Support

PostgreSQL is supported in the multi-db-docker-env project as standalone instances and in two high-availability cluster architectures.

## Supported Versions

- PostgreSQL 17 (Latest stable)
- PostgreSQL 16
- PostgreSQL 15

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PostgreSQL Architectures                     │
├──────────────────┬──────────────────────┬───────────────────────┤
│   Standalone     │   Patroni + ETCD     │   PgPool-II + HAProxy │
│   (Single Node)  │   (HA Cluster)       │   (Pool + LB)         │
├──────────────────┼──────────────────────┼───────────────────────┤
│ postgres15       │ 3 ETCD nodes         │ 3 PostgreSQL 17 nodes │
│ postgres16       │ 3 PostgreSQL 17      │ PgPool-II 4.4         │
│ postgres17       │ HAProxy (RW/RO)      │ HAProxy (RW/RO)       │
│                  │ Supervisord          │ Streaming Replication  │
├──────────────────┼──────────────────────┼───────────────────────┤
│ make postgres17  │ make patroni-up      │ make pgpool-up         │
│ make test-all    │ make test-patroni    │ make test-pgpool       │
└──────────────────┴──────────────────────┴───────────────────────┘
```

---

## 1. Standalone Instances

### Quick Start

```bash
make postgres17    # PostgreSQL 17
make postgres16    # PostgreSQL 16
make postgres15    # PostgreSQL 15
```

### Connection Details

| Setting | Value |
| :--- | :--- |
| Host | `127.0.0.1` |
| Port (Traefik) | `5432` |
| User | `postgres` |
| Password | Defined by `DB_ROOT_PASSWORD` in `.env` |

### Client Connection

```bash
PGPASSWORD=$DB_ROOT_PASSWORD psql -h 127.0.0.1 -p 5432 -U postgres
```

### Makefile Targets

| Command | Description |
| :--- | :--- |
| `make pgpass` | Generate `~/.pgpass` for passwordless connections. |
| `make pgclient` | Open an interactive `psql` session. |
| `make status` | Check running container status. |

---

## 2. Patroni Cluster (RHEL 8)

High-availability PostgreSQL 17 cluster using Patroni and ETCD with automatic failover.

See [patroni_cluster.md](patroni_cluster.md) for full details.

### Architecture

- **ETCD Cluster**: 3 nodes for distributed consensus.
- **PostgreSQL Nodes**: 3 nodes managed by Patroni.
- **HAProxy**: RW (port `5000`) / RO (port `5001`) / Stats (port `7000`).
- **Images**: Custom RHEL 8 (UBI) images (`patroni-rhel8-*`).

### Quick Start

```bash
make patroni-up        # Start cluster
make patroni-status    # Check cluster status
make test-patroni      # Run functional tests
make patroni-down      # Stop cluster
```

### Key Features

- Automatic leader election and failover via Patroni.
- Mutual TLS between all nodes and ETCD.
- Supervisord-based process management.
- Read/Write splitting via HAProxy.

---

## 3. PgPool-II Cluster

Connection pooling and load balancing cluster using PgPool-II with streaming replication.

See [pgpool_cluster.md](pgpool_cluster.md) for full details.

### Architecture

- **PostgreSQL**: 3 nodes (1 primary + 2 standbys) with streaming replication.
- **PgPool-II 4.4**: Connection pooling, load balancing, read/write splitting.
- **HAProxy**: RW (port `5100`) / RO (port `5101`) / Stats (port `8406`).
- **Replication**: Automated setup via `pg_basebackup` + replication slots.

### Quick Start

```bash
make pgpool-up         # Start cluster (auto-configures replication)
make pgpool-status     # Show PgPool node status
make test-pgpool       # Run functional tests (20 tests)
make pgpool-down       # Stop cluster
```

### Key Features

- Automated streaming replication setup (base backup + slots).
- PgPool-II connection pooling (32 children, 4 max pool).
- Load balancing across primary and standbys.
- Write isolation enforced on standbys.

---

## Comparison Matrix

| Feature | Standalone | Patroni | PgPool-II |
| :--- | :--- | :--- | :--- |
| **Nodes** | 1 | 3 PG + 3 ETCD | 3 PG |
| **Automatic Failover** | ❌ | ✅ | ❌ |
| **Connection Pooling** | ❌ | ❌ | ✅ |
| **Load Balancing** | ❌ | ✅ (HAProxy) | ✅ (PgPool + HAProxy) |
| **Read/Write Splitting** | ❌ | ✅ | ✅ |
| **Replication** | ❌ | Synchronous | Async Streaming |
| **TLS/SSL** | ❌ | ✅ Mutual TLS | ❌ (trust in lab) |
| **Test Count** | 1 | 4 | 20 |
| **Use Case** | Dev/Testing | Production HA | Pool + Read Scale |
