---
trigger: always_on
description: Technical environment and infrastructure architecture
category: governance
---
# 02 Architecture: High-Performance Laboratory

## 🧠 Rationale

A well-defined architecture ensures infrastructure stability and reproducibility. This project provides a multi-engine database catalog orchestrated via Docker Compose, the `./mdb` CLI, and `Makefile` compatibility wrappers.

## 🛠️ Implementation

### Technology Stack

- **Language**: Go (`./mdb` CLI), Bash (Shell Scripts), Python, Makefile.
- **DBMS**: Multi-engine catalog (MySQL 8.4/9.7 LTS, MariaDB 10.11/11.4/11.8/12.3 LTS, Percona Server 8.4 LTS, PostgreSQL 15-18, MongoDB 7.0/8.0, CockroachDB v25.4, YugabyteDB 2026.1.3).
- **Orchestration**: `./mdb` CLI, Docker, Docker Compose, Traefik, HAProxy.

### Component Map ($$IMMUTABLE$$)

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| `scripts/` | Performance and tuning scripts (EXPLAIN and sysbench) | 🔴 HIGH |
| `Makefile` | Main command orchestrator (Up, Down, Test, ...) | 🟡 MEDIUM |
| `documentation/` | Technical Markdown documentation | 🟢 MEDIUM |

## ✅ Verification

- Validate `Makefile` entry points.
- Verify `scripts/` directory existence and permissions.
- Run `./mdb doctor` and `make test-config` to validate runtime requirements.
