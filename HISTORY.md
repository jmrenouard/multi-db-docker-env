* [2026-01-10] Relocated `test_db` cloning directory to `/var/tmp/test_db` in Makefile to optimize I/O and keep repo clean.
* [2026-01-10] Added `check-galera` and `check-repli` targets to Makefile for cluster health monitoring.
* [2026-01-10] Applied `innodb_flush_method = O_DSYNC` optimization to all Galera nodes to fix `ERROR 14` on WSL2 filesystems.
* [2026-01-10] Added `tmpfs` mount for `/tmp` to all Galera nodes in `docker-compose-galera.yml`.
* [2026-01-10] Standardized Makefile commands to use the `mariadb` host client instead of `docker exec` for all status checks and administrative tasks (FLUSH SSL), ensuring consistency with data injection commands.
* [2026-01-09] fix: corrected emergency startup targets and replaced docker exec with mariadb host client in Makefile.
* [2026-01-09] Improved Galera cluster resilience: added `wsrep_slave_threads=1` and tuned Flow Control (`gcs.fc_factor=0.8`, `gcs.fc_limit=32`) in `gcustom_*.cnf` files.
* [2026-01-09] Implemented `make renew-ssl-repli` for zero-downtime SSL rotation on Replication clusters.
* [2026-01-09] Optimized MariaDB configuration in `gcustom_*.cnf` with recommended parameters (InnoDB buffer/log sizes, `max_connections`, `query_cache`, etc.).
* [2026-01-09] Added `make inject-*-galera` and `make inject-*-repli` commands to automate full deployment and sample data injection (Employees/Sakila) from github.com/jmrenouard/test_db.
* [2026-01-09] Full translation of CONTEXT.md and HISTORY.md files into English.
* [2026-01-08] Centralization of ALL test reports (Galera, Replication, Sysbench Performance, HAProxy) in the `reports/` directory and update of associated documentation.
* [2026-01-08] Integration of SSL expiration monitoring (30 days) and "Best Practices" Galera audit in `test_galera.sh`.
* [2026-01-08] Implementation of hot SSL rotation (`make renew-ssl`) with reload via `FLUSH SSL`.
* [2026-01-08] Redesign of Galera Provider Options display: transition from a unit test to a dedicated information block in reports.
* [2026-01-08] Optimization of `gen_ssl.sh` script: added existing validity check to avoid unnecessary regenerations.
* [2026-01-08] Resolution of "Aborted connection" errors in MariaDB logs: switch of HAProxy health check from `tcp-check` to `mysql-check` with a dedicated user `haproxy_check`.
* [2026-01-08] Integration of formatted validation of `wsrep_provider_options` variables in Galera test reports (`test_galera.sh`).
* [2026-01-07] Integration of dynamic architecture diagrams (Mermaid.js) in Galera and Replication HTML reports.
* [2026-01-07] Correction of log commands in Makefile: separation between static reading (`logs-*`) and dynamic stream (`follow-*`).
* [2026-01-07] Addition of `make logs-error-*` and `make logs-slow-*` targets in Makefile for container diagnosis.
* [2026-01-07] Refactoring of `gcustom_*.cnf` and `custom_*.cnf` files: structuring by themes and documentation of parameters in English.
* [2026-01-07] Automatic correction of `id_rsa` permissions (600) in `gen_profiles.sh` for SSH access.
* [2026-01-07] Addition of SSH aliases (`ssh-g*`, `ssh-m*`) in shell profiles to facilitate container access.
* [2026-01-07] Transition to a "Single Branch" approach on `main` to simplify the development flow.
* [2026-01-07] Integration of "Conventional Commits" and "Feature Branch" rules in the development cycle.
* [2026-01-07] Validation of immediate commit rule and Git archiving of changes (PFS/SlowQuery).
* [2026-01-07] Addition of test update rule in CONTEXT.md and integration of PFS/SlowQuery verification in `test_galera.sh`.
* [2026-01-07] Verification and application of Galera configuration (PFS and Slow Query Log). Cluster restart performed successfully.
* [2026-01-07] Reinforcement of Bash robustness rules (Addition of explicit verification of critical commands).  
* [2025-01-01] Initialization of AI context for MariaDB Docker environment (Galera/Replication).
