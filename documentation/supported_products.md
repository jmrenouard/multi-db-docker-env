# Supported Products

Comprehensive reference of all database engines and infrastructure components supported by the project.

## 🐬 MySQL

| Version | Docker Image | Standalone Port | TLS | TDE | Support Window / EOL | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 9.7 LTS | `mysql:9.7` | `3306` (Traefik) | ❌ | Local keyring file ([TDE](tde_encryption.md)) | 2031-04-30 (Ext. 2034-04-30) | ✅ Verified |
| 8.4 LTS | `mysql:8.4` | `3306` (Traefik) | ❌ | Local keyring file ([TDE](tde_encryption.md)) | 2029-04-30 (Ext. 2032-04-30) | ✅ Verified |

**HA Mode**: InnoDB Cluster (3-node MySQL 8.4 LTS Group Replication + HAProxy)

## 🐬 MariaDB

| Version | Docker Image | Standalone Port | TLS | TDE | Community EOL | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 12.3 LTS | `mariadb:12.3` | `3306` (Traefik) | ✅ (cluster) | ✅ Native + rotation ([TDE](tde_encryption.md)) | 2029-06-12 | ✅ Verified |
| 11.8 LTS | `mariadb:11.8` | `3306` (Traefik) | ✅ (cluster) | ✅ Native + rotation ([TDE](tde_encryption.md)) | 2028-06-04 | ✅ Verified |
| 11.4 LTS | `mariadb:11.4` | `3306` (Traefik) | ✅ (cluster) | ✅ Native ([TDE](tde_encryption.md)) | 2029-05-29 | ✅ Verified |
| 10.11 LTS | `mariadb:10.11` | `3306` (Traefik) | ✅ (cluster) | ✅ Native ([TDE](tde_encryption.md)) | 2028-02-16 | ✅ Verified |

**HA Modes**:
- Galera Cluster (3-node synchronous replication, ports 3511-3513)
- Master/Slave Replication (1 master + 2 slaves, ports 3411-3413)

## 🐬 Percona Server

| Version | Docker Image | Standalone Port | TLS | TDE | Community EOL | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 8.4 LTS | `percona/percona-server:8.4` | `3306` (Traefik) | ❌ | ✅ Open-source KMS ([TDE](tde_encryption.md)) | 2029-04-30 | ✅ Verified |

## 🐘 PostgreSQL

| Version | Docker Image | Standalone Port | TLS | TDE | Community EOL | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 18 | `postgres:18` | `5432` (Traefik) | ❌ | OS / LUKS ([TDE](tde_encryption.md)) | 2030-11-14 | ✅ Verified |
| 17 | `postgres:17` | `5432` (Traefik) | ❌ | OS / LUKS ([TDE](tde_encryption.md)) | 2029-11-08 | ✅ Verified |
| 16 | `postgres:16` | `5432` (Traefik) | ❌ | OS / LUKS ([TDE](tde_encryption.md)) | 2028-11-09 | ✅ Verified |
| 15 | `postgres:15` | `5432` (Traefik) | ❌ | OS / LUKS ([TDE](tde_encryption.md)) | 2027-11-11 | ✅ Verified |

**HA, Replication & Multi-Master Modes (31/31 Active Environments Verified Live E2E)**:
- Patroni Cluster (3 PG 17 + 3 etcd 3.5.17 + HAProxy LTS, ports 5000/5001/7000 HTTPS, mTLS): self-contained non-root Dockerfiles (`scripts/patroni/Dockerfile.{etcd,postgresql,haproxy}`), auto-built by `./mdb up patroni` or `./mdb images build patroni` — no external pre-built images needed (see [patroni_cluster.md](patroni_cluster.md)).
- PgPool-II Cluster (3 PG 17 + PgPool 4.4.3 + HAProxy, ports 5100/5101/8406)
- Replication, Multi-Master & Distributed SQL (all 13 PG Compose stacks, `v2.1.0`–`v2.5.0`): `pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pg18-streaming`, `pg18-logical`, `pg18-birep`, `yt-cluster` ([`dbinvent/yt:1.21.3`](https://hub.docker.com/r/dbinvent/yt), PG 18.7), `pgedge` (Spock 5), `bucardo`, `citus` (14.2), `cockroach` (`latest-v25.4`), `yugabyte` (`2026.1.3`).
- `yt-cluster` Licensing & Benchmarks: MIT [`DBinvent/yt-cluster-lite`](https://github.com/DBinvent/yt-cluster-lite) single-DB leaf vs PolyForm Noncommercial 1.0.0 / Commercial (`ytserv`/`ytctl`). See [Overview](https://dbinvent.com/30p), [`agent.md`](https://dbinvent.com/agent.md), [Jepsen `1.20.1`](https://dbinvent.com/cluster/articles/jepsen) (`cursor-stability`, `51` -> `49/49`), and [pg_multimaster.md](pg_multimaster.md).
- Storage Encryption (TDE): Community PG stacks use LUKS or ZFS. Read [tde_encryption.md](tde_encryption.md) for `pg_tde` 2.1, YugabyteDB, and CockroachDB.
- Unified CLI Access: Run `./mdb catalog` (`31` active + `5` EOL) or `./mdb up <env>`.

## 🍃 MongoDB

| Version | Docker Image | Standalone Port | TLS | TDE | Community EOL | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 8.0 LTS | `mongo:8.0` | — | ✅ (cluster) | OS / CSFLE ([TDE](tde_encryption.md)) | 2029-10-31 | ✅ Verified |
| 7.0 | `mongo:7.0` | — | ✅ (cluster) | OS / CSFLE ([TDE](tde_encryption.md)) | 2027-08-31 | ✅ Verified |

**HA Mode**: ReplicaSet (3-node rs0 + HAProxy)
- MongoDB 7: ports 27411-27413 / HAProxy 27100 / Stats 8408
- MongoDB 8: ports 27511-27513 / HAProxy 27200 / Stats 8409

## 🔧 Infrastructure Components

| Component | Image | Role | Ports |
| :--- | :--- | :--- | :--- |
| Traefik | `traefik:v3` | Reverse proxy for standalone DBs | `3306`, `5432`, `8080` (dashboard) |
| HAProxy | `haproxy:lts` / `haproxy:lts-alpine` | TCP load balancer for HA clusters | Per-cluster (see docs) |
| ETCD | `quay.io/coreos/etcd:v3.5.17` (`scripts/patroni/Dockerfile.etcd`) | Distributed consensus for Patroni (`patroni-rhel8-etcd:latest`) | `2379`, `2380` |

> **E2E Image Inventory (`./mdb images`)**: All **31** required E2E Docker images (`7` custom builds: `mariadb_ssh:004`, `multi-db-bucardo-{pg17,daemon}:latest`, `patroni-rhel8-{etcd,postgresql,haproxy}:latest`, `multi-db-pgbench-sysbench:latest`; plus `24` pinned upstream images across standalone, clusters, and test helpers) run with `./mdb images list|build|pull|check` (`make build-images`, `make pull-images`, `make check-images`).

## 🛑 Decommissioned Versions (End-of-Life)

These versions reached community End-of-Life (EOL) and left active Compose stacks. Run `./mdb catalog --eol` to list them. Both `./mdb up <eol>` and legacy `Makefile` targets exit `1` with the EOL date and replacement.

| Product | Decommissioned Version | Official EOL Date | Decommissioning Note | Recommended Replacement |
| :--- | :--- | :--- | :--- | :--- |
| MySQL | `5.7` (`mysql:5.7`) | **2023-10-31** | Premier EOL 2023-10-31 (Extended ended 2026-10-31); removed from standalone stack | `mysql:8.4` (`make mysql84`) or `mysql:9.7` (`make mysql97`) |
| MySQL | `8.0` (`mysql:8.0`) | **2026-04-30** | Oracle Community EOL reached; standalone and InnoDB Cluster migrated to 8.4 LTS | `mysql:8.4` (`make mysql84` / `make innodb-up`) or `mysql:9.7` (`make mysql97`) |
| MySQL | `9.6` (`mysql:9.6`) | **2026-04-21** | Innovation release superseded by MySQL 9.7 LTS | `mysql:9.7` (`make mysql97`) |
| MariaDB | `10.6` (`mariadb:10.6`) | **2026-07-06** | Community maintenance period ended; removed from standalone stack | `mariadb:10.11` (`make mariadb1011`), `mariadb:11.4` (`make mariadb114`), or `mariadb:12.3` (`make mariadb123`) |
| Percona Server | `8.0` (`percona/percona-server:8.0`) | **2026-04-30** | Mirrors MySQL 8.0 EOL; public community updates ended | `percona/percona-server:8.4` (`make percona84`) |
| Traefik | `v2.11` (`traefik:v2.11`) | **2026-09-07** | Security support ended; standalone reverse proxy upgraded to v3 | `traefik:v3` |
| HAProxy | `2.9` (`haproxy:2.9-alpine`) | **2025-03-21** | Short-Term Support (STS) EOL; PostgreSQL cluster proxies upgraded to LTS | `haproxy:lts-alpine` / `haproxy:lts` |

## 📊 Networking Matrix

| Cluster | Subnet | Nodes | Router |
| :--- | :--- | :--- | :--- |
| Replication | `10.5.0.0/24` | 3 MariaDB | — |
| Galera | `10.6.0.0/24` | 3 MariaDB | — |
| PgPool-II | `10.8.0.0/24` | 3 PG + PgPool + HAProxy | HAProxy |
| InnoDB Cluster | `10.9.0.0/24` | 3 MySQL + HAProxy | HAProxy |
| MongoDB RS (7.0) | `10.10.0.0/24` | 3 MongoDB + HAProxy | HAProxy |
| MongoDB RS (8.0) | `10.11.0.0/24` | 3 MongoDB + HAProxy | HAProxy |
| Patroni | Docker bridge | 3 PG + 3 ETCD + HAProxy | HAProxy |
