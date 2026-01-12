## **2\. 🎯 OPERATIONAL OBJECTIVE (Manual Update Required)**

$$DYNAMIC\_CONTEXT$$

* **Status:** \[IN PROGRESS\]  
* **Priority Task:** Realize a complete Docker environment for MariaDB integrating Galera Cluster and Master-Slave Replication, with automated maintenance scripts (Backup/Restore) and orchestration via Makefile.

**Success Criteria:**

1. **Orchestration:** All features integrated into Makefile.  
2. **Lifecycle:** Docker environments (Galera & Replication) must start/stop cleanly via make.  
3. **Robustness:** Bash scripts must use set \-e and be portable.  
4. **Persistence:** Backup/Restore must function on persistent volumes.  
5. **Documentation:** Exhaustive Markdown documentation with deployment/testing instructions.  
6. **Goal:** Provide a stable, reproducible platform for performance/resilience testing.
