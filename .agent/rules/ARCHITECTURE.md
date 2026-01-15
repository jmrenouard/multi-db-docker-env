---
trigger: always_on
---

# 🏗️ TECHNICAL ENVIRONMENT & ARCHITECTURE

$$IMMUTABLE$$
Component Map:
Modification prohibited without explicit request.

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| scripts/ | performance and tuning scripts (EXPALIN and sysbench) | 🔴 HIGH |
| Makefile | Main command orchestrator (Up, Down, Test, ...) | 🟡 MEDIUM |
| documentation/ | Technical Markdown documentation | 🟢 MEDIUM |

**Technology Stack:**

* **Language:** Bash (Shell Scripts), Python, Makefile
* **DBMS:** MariaDB 11.8 (Custom Docker Images)
* **Orchestration:** Docker, Docker Compose
