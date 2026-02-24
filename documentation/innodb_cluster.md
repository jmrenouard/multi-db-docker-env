# MySQL InnoDB Cluster

MySQL 8.0 cluster with Group Replication and HAProxy for transparent connection routing.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Network: 10.9.0.0/24                       │
│                                                               │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                  │
│  │mysql_node1│   │mysql_node2│  │mysql_node3│                 │
│  │ PRIMARY   │   │SECONDARY │   │SECONDARY │                  │
│  │ 10.9.0.11│   │ 10.9.0.12│   │ 10.9.0.13│                  │
│  │ :4411    │   │ :4412    │   │ :4413    │                    │
│  └────┬─────┘   └─────┬────┘   └─────┬────┘                  │
│       │  Group         │              │                       │
│       │  Replication   │              │                       │
│       ▼                ▼              ▼                       │
│  ┌─────────────────────────────────────────┐                  │
│  │           HAProxy                       │                  │
│  │    RW :6446  │  RO :6447               │                  │
│  │    Stats :8407  │  10.9.0.20            │                  │
│  └─────────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
```

### Components

| Component | Image | IP | Role |
| :--- | :--- | :--- | :--- |
| `mysql_node1` | `mysql:8.0` | `10.9.0.11` | Primary (read/write) |
| `mysql_node2` | `mysql:8.0` | `10.9.0.12` | Secondary (read-only) |
| `mysql_node3` | `mysql:8.0` | `10.9.0.13` | Secondary (read-only) |
| `haproxy_innodb` | `haproxy:lts` | `10.9.0.20` | Connection routing (RW/RO) |

## Quick Start

### 1. Start the Cluster

```bash
make innodb-up
```

This command:
- Starts 3 MySQL 8.0 nodes + HAProxy
- Waits for all nodes to initialize
- Configures Group Replication (creates replication user, bootstraps primary, joins secondaries)
- HAProxy auto-bootstraps against the cluster

### 2. Check Status

```bash
make innodb-status
make innodb-ps
make innodb-logs
```

## Connection Details

| Role | Port | Description |
| :--- | :--- | :--- |
| HAProxy Read-Write | `6446` | Write traffic routed to primary. |
| HAProxy Read-Only | `6447` | Read traffic round-robin across secondaries. |
| HAProxy Stats | `8407` | HAProxy stats dashboard. |
| MySQL Node 1 (Primary) | `4411` | Direct access to primary node. |
| MySQL Node 2 (Secondary) | `4412` | Direct access to secondary node 2. |
| MySQL Node 3 (Secondary) | `4413` | Direct access to secondary node 3. |

### Example Connection

```bash
# Via HAProxy Read-Write (recommended)
mysql -h 127.0.0.1 -P 6446 -uroot -p"$DB_ROOT_PASSWORD"

# Via HAProxy Read-Only
mysql -h 127.0.0.1 -P 6447 -uroot -p"$DB_ROOT_PASSWORD"

# Direct to primary node
mysql -h 127.0.0.1 -P 4411 -uroot -p"$DB_ROOT_PASSWORD"
```

## Group Replication Configuration

| Parameter | Value |
| :--- | :--- |
| `gtid-mode` | ON |
| `enforce-gtid-consistency` | ON |
| `binlog-format` | ROW |
| `group-replication-group-seeds` | `mysql_node1:33061,mysql_node2:33061,mysql_node3:33061` |
| `transaction-write-set-extraction` | XXHASH64 |

## Automated Testing

```bash
make test-innodb
```

Test suite validates **15 checks across 10 test groups**:

| # | Test | Description |
| :--- | :--- | :--- |
| 1 | Node Status | All 3 MySQL nodes UP with version info |
| 2 | Group Replication | 3 ONLINE members |
| 3 | HAProxy | RW (6446) and RO (6447) connectivity |
| 4 | Write Replication | Write on primary, verify on secondaries |
| 5 | Write Isolation | Secondaries reject writes |
| 6 | DDL Replication | ALTER TABLE replicated |
| 7 | Version Consistency | All nodes same MySQL version |
| 8 | Concurrent Writes | 30 rows via Router |
| 9 | Router Routing | RW port routes to primary |
| 10 | GTID Consistency | GTID active across cluster |

Reports generated in `./reports/` (Markdown + HTML).

## Cleanup

```bash
make innodb-down
```

Removes all containers, networks, and volumes for a clean restart.
