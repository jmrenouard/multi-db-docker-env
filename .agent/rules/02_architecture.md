---
trigger: always_on
description: Technical environment and infrastructure architecture
category: governance
---
# 02 Architecture: High-Performance Laboratory

## 🧠 Rationale

A well-defined architecture ensures infrastructure stability and reproducibility. This project relies on a custom MariaDB 11.8 stack orchestrated via Docker Compose and controlled by a robust Makefile.

## 🛠️ Implementation

### Technology Stack

- **Language**: Bash (Shell Scripts), Python, Makefile.
- **DBMS**: MariaDB 11.8 (Custom Docker Images).
- **Orchestration**: Docker, Docker Compose.

### Component Map ($$IMMUTABLE$$)

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| `scripts/` | Performance and tuning scripts (EXPLAIN and sysbench) | 🔴 HIGH |
| `Makefile` | Main command orchestrator (Up, Down, Test, ...) | 🟡 MEDIUM |
| `documentation/` | Technical Markdown documentation | 🟢 MEDIUM |

## ✅ Verification

- Validate `Makefile` entry points.
- Verify `scripts/` directory existence and permissions.
- Run `make check-env` (if available) to validate runtime requirements.
