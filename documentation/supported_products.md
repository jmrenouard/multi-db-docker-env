# Supported Products

Comprehensive reference of all database engines and infrastructure components supported by the project.

## 🐬 MySQL

| Version | Docker Image | Standalone Port | TLS | Status |
| :--- | :--- | :--- | :--- | :--- |
| 9.6 | `mysql:9.6` | `3306` (via Traefik) | ❌ | ✅ Verified |
| 8.4 | `mysql:8.4` | `3306` (via Traefik) | ❌ | ✅ Verified |
| 8.0 | `mysql:8.0` | `3306` (via Traefik) | ❌ | ✅ Verified |
| 5.7 | `mysql:5.7` | `3306` (via Traefik) | ❌ | ✅ Verified |

**HA Mode**: InnoDB Cluster (3-node Group Replication + HAProxy)

## 🐬 MariaDB

| Version | Docker Image | Standalone Port | TLS | Status |
| :--- | :--- | :--- | :--- | :--- |
| 11.8 | `mariadb:11.8` | `3306` (via Traefik) | ✅ (cluster) | ✅ Verified |
| 11.4 | `mariadb:11.4` | `3306` (via Traefik) | ✅ (cluster) | ✅ Verified |
| 10.11 | `mariadb:10.11` | `3306` (via Traefik) | ✅ (cluster) | ✅ Verified |
| 10.6 | `mariadb:10.6` | `3306` (via Traefik) | ✅ (cluster) | ✅ Verified |

**HA Modes**:
- Galera Cluster (3-node synchronous replication, ports 3511-3513)
- Master/Slave Replication (1 master + 2 slaves, ports 3611-3613)

## 🐬 Percona Server

| Version | Docker Image | Standalone Port | TLS | Status |
| :--- | :--- | :--- | :--- | :--- |
| 8.4 | `percona:8.4` | `3306` (via Traefik) | ❌ | ✅ Verified |
| 8.0 | `percona:8.0` | `3306` (via Traefik) | ❌ | ✅ Verified |

## 🐘 PostgreSQL

| Version | Docker Image | Standalone Port | TLS | Status |
| :--- | :--- | :--- | :--- | :--- |
| 17 | `postgres:17` | `5432` (via Traefik) | ❌ | ✅ Verified |
| 16 | `postgres:16` | `5432` (via Traefik) | ❌ | ✅ Verified |
| 15 | `postgres:15` | `5432` (via Traefik) | ❌ | ✅ Verified |

**HA Modes**:
- Patroni Cluster (3 PG 17 + 3 ETCD + HAProxy, ports 5000/5001/7000)
- PgPool-II Cluster (3 PG 17 + PgPool + HAProxy, ports 5100/5101/8406)

## 🍃 MongoDB

| Version | Docker Image | Standalone Port | TLS | Status |
| :--- | :--- | :--- | :--- | :--- |
| 8.0 | `mongo:8.0` | — | ❌ | ✅ Verified |
| 7.0 | `mongo:7.0` | — | ❌ | ✅ Verified |

**HA Mode**: ReplicaSet (3-node rs0 + HAProxy)
- MongoDB 7: ports 27411-27413 / HAProxy 27100 / Stats 8408
- MongoDB 8: ports 27511-27513 / HAProxy 27200 / Stats 8409

## 🔧 Infrastructure Components

| Component | Image | Role | Ports |
| :--- | :--- | :--- | :--- |
| Traefik | `traefik:v2.10` | Reverse proxy for standalone DBs | `3306`, `5432`, `8080` (dashboard) |
| HAProxy | `haproxy:lts` | TCP load balancer for HA clusters | Per-cluster (see docs) |
| ETCD | `quay.io/coreos/etcd:v3.5.21` | Distributed config for Patroni | `2379`, `2380` |

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
