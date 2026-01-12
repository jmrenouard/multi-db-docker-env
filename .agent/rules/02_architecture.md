## **3\. 🏗️ TECHNICAL ENVIRONMENT & ARCHITECTURE**

$$IMMUTABLE$$  
Component Map:  
Modification prohibited without explicit request.  
| File/Folder | Functionality | Criticality |  
| Makefile | Main command orchestrator (Up, Down, Test, Backup) | 🔴 HIGH |  
| docker-compose.yaml | Infrastructure definition (Networks, Volumes, Services) | 🔴 HIGH |  
| scripts/ | Maintenance scripts (Backup, Restore, Setup, Healthcheck) | 🟡 MEDIUM |  
| config/ | MariaDB configuration files (my.cnf, galera.cnf) | 🟡 MEDIUM |  
| documentation/ | Technical Markdown documentation | 🟢 LOW |  
**Technology Stack:**

* **Language:** Bash (Shell Scripts), Makefile  
* **DBMS:** MariaDB 11.8 (Custom Docker Images)  
* **Orchestration:** Docker, Docker Compose  
* **Proxy:** HAProxy (Load Balancing Galera/Replication)
