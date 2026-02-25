# MariaDB Documentation Index 📚

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="50" height="50">
  <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="50" height="50">
</p>

Welcome to the MariaDB Docker environment documentation. This index provides a structured overview of all available guides and technical references.

---

## 📋 Table of Contents

- [MariaDB Documentation Index 📚](#mariadb-documentation-index-)
  - [📋 Table of Contents](#-table-of-contents)
  - [🚀 Core Documentation](#-core-documentation)
  - [🏛️ Governance \& Orchestration](#️-governance--orchestration)
  - [🛠️ Management \& Automation](#️-management--automation)
  - [🔄 Replication \& Galera](#-replication--galera)
  - [🐘 PostgreSQL \& HA Architectures](#-postgresql--ha-architectures)
  - [🐬 Standalone Matrix](#-standalone-matrix)
  - [🧪 Testing \& Performance](#-testing--performance)
  - [🔗 MariaDB Replication Overview](#-mariadb-replication-overview)

---

## 🚀 Core Documentation

| Document | Description |
| --- | --- |
| **[Main README](../README.md)** | Overview, quick start, build instructions, and basic usage. |
| **[Architecture](architecture.md)** | Global topology, network layout, and detailed Mermaid diagrams. |

## 🏛️ Governance & Orchestration

| Document | Description |
| --- | --- |
| **[Constitution](../.agent/rules/00_constitution.md)** | Absolute source of truth for project principles and Operational Authority. |
| **[Super Manager](../.agent/workflows/go-agent.md)** | Orchestration protocol for coordinating skills, rules, and workflows. |

## 🛠️ Management & Automation

| Document | Description |
| --- | --- |
| **[Makefile Reference](makefile.md)** | Detailed breakdown of all `make` commands for automated deployment and maintenance. |
| **[Utility Scripts](scripts.md)** | Deep dive into backup, restore, security (SSL), and setup scripts. |

## 🔄 Replication & Galera

| Document | Description |
| --- | --- |
| **[Galera Bootstrap](galera_bootstrap.md)** | Step-by-step guide for initializing and growing Galera clusters. |
| **[Replication Setup](replication_setup.md)** | How to configure and automate Master/Slave replication. |
| **[SSL & Security](replication_ssl.md)** | Configuring SSL for encrypted connections and secure replication. |

## 🐘 PostgreSQL & HA Architectures

| Document | Description |
| --- | --- |
| **[PostgreSQL Support](postgresql_support.md)** | Complete guide: standalone (15/16/17), Patroni HA, and PgPool-II clusters. |
| **[Patroni Cluster](patroni_cluster.md)** | 3-node PostgreSQL 17 HA cluster with ETCD and automatic failover. |
| **[PgPool-II Cluster](pgpool_cluster.md)** | Connection pooling + load balancing with streaming replication. |

## 🐬 MySQL InnoDB Cluster

| Document | Description |
| --- | --- |
| **[InnoDB Cluster](innodb_cluster.md)** | MySQL 8.0 Group Replication with HAProxy for transparent routing. |

## 🍃 MongoDB ReplicaSet

| Document | Description |
| --- | --- |
| **[MongoDB ReplicaSet](mongo_replicaset.md)** | MongoDB 7.0 ReplicaSet with HAProxy for connection routing. |

## 🐬 Standalone Matrix

| Document | Description |
| --- | --- |
| **[Standalone Engines](tests.md#-00-standalone-matrix-t2-tier)** | Overview of supported standalone engines (MySQL, MariaDB, Percona, PostgreSQL). |

## 🧪 Testing & Performance

| Document | Description |
| --- | --- |
| **[Test Cases](tests.md)** | Automated functional test descriptions, expected results, and reporting details. |
| **[Supported Products](supported_products.md)** | Comprehensive matrix of all supported DB engines, versions, ports, and HA modes. |

---

## 🔗 MariaDB Replication Overview

The Replication setup in this project implements a traditional **Master/Slave** architecture, enhanced for modern production needs:

- **GTID-based**: Uses Global Transaction IDs for easy slave promotion and robust consistency.
- **SSL Encrypted**: All replication traffic between the master and slaves is fully encrypted.
- **Automated Setup**: The `make setup-repli` command automates the entire process (user creation, SSL distribution, and linkage).
- **Read-Only Slaves**: Slaves are automatically configured in read-only mode to prevent data drift.
- **Proxy Protocol**: Prepared for HAProxy integration to handle intelligent read/write splitting.

---

*Note: Most documents are also available in French. See [INDEX_fr.md](INDEX_fr.md).*
