# MariaDB Documentation Index 📚

Welcome to the MariaDB Docker environment documentation. This index provides a structured overview of all available guides and technical references.

---

## 📋 Table of Contents

- [MariaDB Documentation Index 📚](#mariadb-documentation-index-)
  - [📋 Table of Contents](#-table-of-contents)
  - [🚀 Core Documentation](#-core-documentation)
  - [🏛️ Governance \& Orchestration](#️-governance--orchestration)
  - [🛠️ Management \& Automation](#️-management--automation)
  - [🔄 Replication \& Galera](#-replication--galera)
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

## 🐬 Standalone Matrix

| Document | Description |
| --- | --- |
| **[Standalone Engines](tests.md#-00-standalone-matrix-t2-tier)** | Overview of supported standalone engines (MySQL, MariaDB, Percona, PostgreSQL). |
| **[PostgreSQL Support](postgresql_support.md)** | Detailed guide for PostgreSQL 16 and 17 integration. |

## 🧪 Testing & Performance

| Document | Description |
| --- | --- |
| **[Test Cases](tests.md)** | Automated functional test descriptions, expected results, and reporting details. |

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
