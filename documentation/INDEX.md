# Multi-DB Docker Environment Documentation Index 📚

| MariaDB | MySQL | Percona | PostgreSQL | MongoDB | Traefik | Docker |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="44" height="44"> | <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="44" height="44"> |

Welcome to the Multi-DB Docker Environment documentation. This index organizes all guides and references into the four Diataxis quadrants.

---

## 📋 Table of Contents

- [📋 Table of Contents](#-table-of-contents)
- [🚀 Tutorials & Quickstart](#-tutorials--quickstart)
- [🔧 How-To Guides](#-how-to-guides)
- [📖 Reference](#-reference)
- [💡 Explanation](#-explanation)

---

## 🚀 Tutorials & Quickstart

Start here to install tools, launch standalone engines, and verify first connections.

| Document | Description |
| --- | --- |
| **[Main README](../README.md)** | Overview, unified `./mdb` (`mdb.cmd`) quick start, cross-platform setup, and CLI usage. |
| **[Standalone Engines](tests.md#00-standalone-matrix-t2-tier)** | Quickstart overview and T2 test suite for standalone engines (MySQL, MariaDB, Percona, PostgreSQL). |

---

## 🔧 How-To Guides

Follow these task-oriented procedures to deploy, bootstrap, secure, and operate database clusters.

| Document | Description |
| --- | --- |
| **[Galera Bootstrap](galera_bootstrap.md)** | Step-by-step guide to bootstrap and recover MariaDB Galera clusters. |
| **[Replication Setup](replication_setup.md)** | Procedure to configure and verify MariaDB Master/Slave replication. |
| **[Replication SSL](replication_ssl.md)** | Steps to encrypt MariaDB replication traffic and verify `Ssl_cipher`. |
| **[TLS/SSL Architecture & Setup](tls_setup.md)** | Unified X.509 certificate setup across all database clusters. |
| **[Patroni Cluster](patroni_cluster.md)** | 3-node PostgreSQL 17 HA cluster with etcd and automatic failover. |
| **[PgPool-II Cluster](pgpool_cluster.md)** | Connection pooling and read load balancing with streaming replication. |
| **[InnoDB Cluster](innodb_cluster.md)** | MySQL 8.4 LTS Group Replication with HAProxy routing. |
| **[MongoDB ReplicaSet](mongo_replicaset.md)** | MongoDB 7.0 and 8.0 ReplicaSet with HAProxy and TLS. |
| **[PostgreSQL Support](postgresql_support.md)** | Deployment guide for standalone PostgreSQL (15/16/17/18), Patroni HA, and PgPool-II. |
| **[PostgreSQL Multi-Master & Distributed SQL](pg_multimaster.md)** | Setup and benchmarks for all 13 PostgreSQL Compose topologies. |

---

## 📖 Reference

Consult these lookup tables, CLI mappings, test specifications, and governance rules.

| Document | Description |
| --- | --- |
| **[CLI & Makefile Reference](makefile.md)** | Unified `./mdb` (`mdb.cmd`) commands (`catalog`, `up`, `setup`, `lint`, `interactive`, `doctor`) and `Makefile` wrappers. |
| **[Utility Scripts](scripts.md)** | Reference for backup, restore, PKI, Go CLI, and test helper scripts. |
| **[Test Cases](tests.md)** | Automated functional test descriptions, expected results, and reporting details. |
| **[Supported Products](supported_products.md)** | Verified matrix of all active DB engines, EOL versions, ports, and subnets. |
| **[Project Rules (AGENTS.md)](../AGENTS.md)** | Repository architecture, PR diff limits (<15K chars), and mandatory 9-step GitHub workflow. |
| **[Action Logbook & Roadmap](../docs/ACTION_LOGBOOK.md)** | Living record of ongoing and completed actions (`ACT-XXX`). |
| **[RCA Register](../docs/RCA_REGISTER.md)** | Living register of RCAs, dead-ends (`IMP`), approximations (`APP`), and ideas (`IDEA`). |
| **[Project Governance](../.agents/rules/project-governance.md)** | Protocol for systematic Action Logbook and RCA Register updates. |
| **[GitHub Lifecycle Workflow](../.agents/rules/github-workflow.md)** | Standard procedure for GitHub issue creation, branching, PRs, and merges. |
| **[Constitution](../.agent/rules/00_constitution.md)** | Source of truth for project principles and operational rules. |
| **[Super Manager Workflow](../.agent/workflows/go-agent.md)** | Orchestration protocol for skills, rules, and workflows. |

---

## 💡 Explanation

Read these architectural notes to understand topology design, routing, and replication mechanics.

| Document | Description |
| --- | --- |
| **[Architecture](architecture.md)** | Global topology, Traefik/HAProxy routing, observability, and Mermaid diagrams. |

### MariaDB Replication Design Notes

The MariaDB Master/Slave stack uses a primary node and two replicas designed for safe failover:

- **GTID-based**: Uses Global Transaction IDs for deterministic slave promotion and consistency.
- **SSL Encrypted**: Encrypts all replication traffic between the master and slaves.
- **Automated Setup**: Uses `make setup-repli` for user setup, SSL distribution, and stream initialization.
- **Read-Only Slaves**: Keeps replicas read-only to prevent data drift.
- **Proxy Protocol**: Integrates with HAProxy for clean read/write routing.

---

*Note: Most top-level documents also have a French translation in [INDEX_fr.md](INDEX_fr.md).*
