# 🏗️ Structural Health Report

## 1. Semantic Drift

| Item | Found In | Issue | Proposed Fix |
| :--- | :--- | :--- | :--- |
| **Script Naming** | `scripts/` | Mix of `start_mariadb.sh` and `setup_repli.sh`. | Rename `start_mariadb.sh` to `start_mariadb.sh` for underscore consistency. |
| **Makefile Verbs** | `Makefile` | `start` (standalone) vs `mariadb-start-galera`. | Use consistent prefixing: `cluster-start-galera`, `cluster-stop-galera`, etc. |
| **Aliasing** | `Makefile` | `verify` is an alias for `test-config`. | Standardize on `test` for all validation targets. |

## 2. Redundancy

* **Active Service Detection**: The following block is duplicated in `info`, `logs`, `client`, `inject-employees`, `inject-sakila`:

    ```makefile
    DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik | head -n 1); \
    DB_CONTAINER=$$(docker compose ps $${DB_SERVICE} --format "{{.Names}}");
    ```

    *Proposal*: Create a Makefile variable or a small function helper to retrieve these.

* **Wait-for-DB Logic**: Duplicated in `test-all` and potentially other test scripts.
    *Proposal*: Centralize in a `scripts/wait_for_db.sh`.

## 3. Parameter Consistency

* **Variable Names**: `DB_CONTAINER` is used in some targets, while `service` is used as a $(service) parameter in others (`inject-data`).
* **Hardcoding**: `scripts/setup_repli.sh` has hardcoded IPs and ports that should ideally be passed as environment variables or sourced from `.env`.

## 4. Bash Robustness & Constraints

* `scripts/start_mariadb.sh` uses `set -e` but lacks `set -u` and `set -o pipefail`.
* `scripts/setup_repli.sh` lacks all safety flags.
* **Non-Regression**: Ensure all changes are covered by existing `test_config.sh`.

## 5. Refactoring Proposals

1. **Centralize Container Discovery**: Implement a helper in Makefile to avoid `docker compose ps | grep` repetitions.
2. **Harmonize Script Names**: Rename `start_mariadb.sh` to `start_mariadb.sh`.
3. **Add Safety Flags**: Update all scripts to `set -euo pipefail`.
4. **Parameterize Replication Setup**: allow passing Master/Slave configuration via environment variables.

---
*Report generated on 2026-01-16*
