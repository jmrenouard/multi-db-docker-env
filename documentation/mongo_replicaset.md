# MongoDB ReplicaSet

MongoDB 7.0 ReplicaSet cluster with HAProxy for connection routing.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Network: 10.10.0.0/24                      │
│                                                               │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                  │
│  │  mongo1  │   │  mongo2  │   │  mongo3  │                   │
│  │ PRIMARY  │   │SECONDARY │   │SECONDARY │                   │
│  │10.10.0.11│   │10.10.0.12│   │10.10.0.13│                   │
│  │  :27411  │   │  :27412  │   │  :27413  │                   │
│  └────┬─────┘   └─────┬────┘   └─────┬────┘                  │
│       │  ReplicaSet    │              │                       │
│       │    rs0         │              │                       │
│       ▼                ▼              ▼                       │
│  ┌─────────────────────────────────────────┐                  │
│  │           HAProxy                       │                  │
│  │    RW :27100  │  Stats :8408           │                   │
│  │         10.10.0.20                      │                  │
│  └─────────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
```

### Components

| Component | Image | IP | Role |
| :--- | :--- | :--- | :--- |
| `mongo1` | `mongo:7.0` | `10.10.0.11` | Primary (read/write) |
| `mongo2` | `mongo:7.0` | `10.10.0.12` | Secondary (read-only) |
| `mongo3` | `mongo:7.0` | `10.10.0.13` | Secondary (read-only) |
| `haproxy_mongo` | `haproxy:lts` | `10.10.0.20` | Connection routing |

## Quick Start

### 1. Start the Cluster

```bash
make mongo-up
```

This command:
- Starts 3 MongoDB 7.0 nodes + HAProxy
- Waits for all nodes to initialize
- Initiates the ReplicaSet (`rs.initiate()` with 3 members)
- Creates admin user with root privileges
- HAProxy auto-detects backends

### 2. Check Status

```bash
make mongo-status
make mongo-ps
make mongo-logs
```

## Connection Details

| Role | Port | Description |
| :--- | :--- | :--- |
| HAProxy RW | `27100` | Write traffic routed to primary. |
| HAProxy Stats | `8408` | HAProxy stats dashboard. |
| MongoDB Node 1 (Primary) | `27411` | Direct access to primary node. |
| MongoDB Node 2 (Secondary) | `27412` | Direct access to secondary node 2. |
| MongoDB Node 3 (Secondary) | `27413` | Direct access to secondary node 3. |

### Example Connection

```bash
# Via HAProxy (recommended)
mongosh --host 127.0.0.1 --port 27100 -u root -p "$DB_ROOT_PASSWORD" --authenticationDatabase admin

# Direct to primary
mongosh --host 127.0.0.1 --port 27411 -u root -p "$DB_ROOT_PASSWORD" --authenticationDatabase admin

# ReplicaSet connection string
mongosh "mongodb://root:$DB_ROOT_PASSWORD@127.0.0.1:27411,127.0.0.1:27412,127.0.0.1:27413/?replicaSet=rs0&authSource=admin"
```

## ReplicaSet Configuration

| Parameter | Value |
| :--- | :--- |
| ReplicaSet Name | `rs0` |
| Auth Method | keyFile (internal) |
| Primary Priority | `2` (mongo1) |
| Secondary Priority | `1` (mongo2, mongo3) |
| Write Concern | Default (majority) |

## Automated Testing

```bash
make test-mongo
```

Test suite validates **12 checks across 8 test groups**:

| # | Test | Description |
| :--- | :--- | :--- |
| 1 | Node Status | All 3 MongoDB nodes UP with version info |
| 2 | ReplicaSet Members | 3 active members |
| 3 | HAProxy | RW (27100) connectivity |
| 4 | Write Replication | Write on primary, verify on secondaries |
| 5 | Write Isolation | Secondaries reject writes |
| 6 | CRUD Operations | Insert, update, delete on primary |
| 7 | Version Consistency | Same MongoDB version across nodes |
| 8 | RS Config | ReplicaSet name and member count |

Reports generated in `./reports/` (Markdown + HTML).

## Cleanup

```bash
make mongo-down
```

Removes all containers, networks, and volumes for a clean restart.
