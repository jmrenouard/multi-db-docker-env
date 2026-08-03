# 🔐 Unified TLS/SSL Architecture & Setup Guide

This document outlines the unified TLS/SSL infrastructure implemented across all database cluster technologies supported in the `multi-db-docker-env` laboratory.

---

## 🏗️ Architecture Overview

All cluster configurations support end-to-end encrypted transport (client-to-cluster and node-to-node) using X.509 certificates generated locally via OpenSSL.

> **Note**: Certificate directories listed below are relative to the repository root directory (`./ssl/`). At container startup, these host paths are mounted into each container filesystem (e.g., `/etc/ssl/mongo/` or `/etc/ssl/pgpool/`).

| Technology Cluster | Certificate Directory | CA File | Server Cert / Key | Key Config Flags |
| :--- | :--- | :--- | :--- | :--- |
| **MariaDB Galera / Replication** | `ssl/` | `ca-cert.pem` | `server-cert.pem` / `server-key.pem` | `ssl=1`, `ssl-ca`, `ssl-cert`, `ssl-key` |
| **MySQL InnoDB Cluster** | `ssl/innodb/` | `ca-cert.pem` | `server-cert.pem` / `server-key.pem` | `require_secure_transport=ON` |
| **PostgreSQL PgPool-II** | `ssl/pgpool/` | `ca-cert.pem` | `server.crt` / `server.key` | `ssl=on`, `PGPOOL_PARAMS_SSL=on` |
| **MongoDB ReplicaSet** | `ssl/mongo/` | `ca.pem` | `mongodb.pem` (combined) | `--tlsMode requireTLS` |
| **Patroni PostgreSQL** | `ssl/patroni/` | `ca-cert.pem` | `server.crt` / `server.key` | `PG_HBA_SSL_TYPE=hostssl`, `PGSSLMODE=verify-ca` |

---

## 🛠️ Makefile Entrypoints

Unified and per-product Makefile entrypoints simplify certificate generation and validation:

### 1. Generate All TLS Certificates
To generate X.509 certificates for all database engines at once:
```bash
make gen-ssl-all
```

### 2. Verify All TLS Certificates
To verify the expiration and CA chain validity across all clusters:
```bash
make check-ssl-all
```

### 3. Per-Engine Generation Targets
- **MariaDB Galera / Replication**: `make gen-ssl`
- **MySQL InnoDB Cluster**: `make gen-ssl-innodb`
- **PostgreSQL PgPool-II**: `make gen-ssl-pgpool`
- **MongoDB ReplicaSet**: `make gen-ssl-mongo`
- **Patroni PostgreSQL**: `make gen-ssl-patroni`

---

## 🧪 Verification & Audit

Each functional test suite (`make test-*`) automatically verifies TLS/SSL enforcement:

```bash
make test-galera
make test-repli
make test-innodb
make test-pgpool
make test-mongo
make test-patroni
```
