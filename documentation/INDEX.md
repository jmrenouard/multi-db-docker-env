# Multi-DB Docker Environment Documentation Index 📚

| MariaDB | MySQL | Percona | PostgreSQL | MongoDB | Traefik | Docker |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="44" height="44"> | <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="44" height="44"> |

Welcome to the Multi-DB Docker Environment documentation. This index provides a structured overview of all available guides and technical references.

---

## 📋 Table of Contents

- [Multi-DB Docker Environment Documentation Index 📚](#multi-db-docker-environment-documentation-index-)
  - [📋 Table of Contents](#-table-of-contents)
  - [🚀 Core Documentation](#-core-documentation)
  - [🏛️ Governance \& Orchestration](#-governance--orchestration)
  - [🛠️ Management \& Automation](#-management--automation)
  - [🔄 Replication \& Galera](#-replication--galera)
  - [🐘 PostgreSQL \& HA Architectures](#-postgresql--ha-architectures)
  - [🐬 Standalone Matrix](#-standalone-matrix)
  - [🧪 Test Suites \& Benchmarks](#-test-suites--benchmarks)
  - [🔗 MariaDB Replication Overview](#-mariadb-replication-overview)

---

## 🚀 Core Documentation

| Document | Description |
| --- | --- |
| **[Main README](../README.md)** | Overview, unified `./mdb` (`mdb.cmd`) quick start, cross-platform setup, and CLI usage. |
| **[Architecture](architecture.md)** | Global topology, unified orchestrator routing, network layout, and Mermaid diagrams. |

## 🏛️ Governance & Orchestration

| Document | Description |
| --- | --- |
| **[Project Rules (AGENTS.md)](../AGENTS.md)** | Core project architecture, PR diff limits (<15K chars), and mandatory GitHub workflow. |
| **[Action Logbook & Roadmap](../docs/ACTION_LOGBOOK.md)** | Living record of ongoing/completed actions and executive phase progress dashboard. |
| **[RCA Register](../docs/RCA_REGISTER.md)** | Living register of Root Cause Analyses, dead-ends (IMP), approximations (APP), and roadmap (IDEA). |
| **[Project Governance](../.agents/rules/project-governance.md)** | Mandatory protocol for systematic Action Logbook and RCA Register updates. |
| **[GitHub Lifecycle Workflow](../.agents/rules/github-workflow.md)** | Standard operating procedure for Issue creation, dedicated branching, PR, and merge. |
| **[Constitution](../.agent/rules/00_constitution.md)** | Absolute source of truth for project foundation principles and Operational Authority. |
| **[Super Manager Workflow](../.agent/workflows/go-agent.md)** | Orchestration protocol for coordinating skills, rules, and workflows. |

## 🛠️ Management & Automation

| Document | Description |
| --- | --- |
| **[CLI & Makefile Reference](makefile.md)** | Unified `./mdb` (`mdb.cmd`) commands (`catalog`, `up`, `setup`, `lint`, `interactive`, `doctor`) and `Makefile` compatibility wrappers. |
| **[Utility Scripts](scripts.md)** | Deep dive into backup, restore, security (SSL), and setup scripts. |

## 🔄 Replication & Galera

| Document | Description |
| --- | --- |
| **[Galera Bootstrap](galera_bootstrap.md)** | Step-by-step guide for initializing and growing Galera clusters. |
| **[Replication Setup](replication_setup.md)** | How to configure and automate Master/Slave replication. |
| **[SSL & Security](replication_ssl.md)** | Configuring SSL for encrypted connections and secure replication. |
| **[TLS/SSL Architecture](tls_setup.md)** | Unified TLS/SSL architecture and setup guide across all database technologies. |

## 🐘 PostgreSQL & HA Architectures

| Document | Description |
| --- | --- |
| **[PostgreSQL Support](postgresql_support.md)** | Complete guide: standalone (15/16/17/18), Patroni HA, and PgPool-II clusters. |
| **[PostgreSQL Multi-Master & Distributed SQL](pg_multimaster.md)** | `pg17-baseline`, `pg-streaming`/`logical`/`birep`, `pg18-*`, `yt-cluster` 1.21.3, pgEdge Spock 5, Bucardo 5, Citus 14.2, YugabyteDB 2026.1, and CockroachDB v25.4 guide & benchmarks. |
| **[Patroni Cluster](patroni_cluster.md)** | 3-node PostgreSQL 17 HA cluster with ETCD and automatic failover. |
| **[PgPool-II Cluster](pgpool_cluster.md)** | Connection pooling + load balancing with streaming replication. |

## 🐬 MySQL InnoDB Cluster

| Document | Description |
| --- | --- |
| **[InnoDB Cluster](innodb_cluster.md)** | MySQL 8.4 LTS Group Replication with HAProxy for transparent routing. |

## 🍃 MongoDB ReplicaSet

| Document | Description |
| --- | --- |
| **[MongoDB ReplicaSet](mongo_replicaset.md)** | MongoDB 7.0 and 8.0 ReplicaSet with HAProxy for connection routing. |

## 🐬 Standalone Matrix

| Document | Description |
| --- | --- |
| **[Standalone Engines](tests.md#00-standalone-matrix-t2-tier)** | Overview of supported standalone engines (MySQL, MariaDB, Percona, PostgreSQL). |

## 🧪 Test Suites & Benchmarks

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
- **Read-Only Slaves**: Slaves stay read-only to prevent data drift.
- **Proxy Protocol**: Prepared for HAProxy integration to handle clean read/write routing.

---

*Note: Most documents are also available in French. See [INDEX_fr.md](INDEX_fr.md).*
