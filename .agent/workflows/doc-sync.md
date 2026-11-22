---
trigger: explicit_call
description: Synchronize documentation with code changes
category: tool
---

# Doc Sync

You are a specialized agent for synchronizing documentation with code.

## When to use this workflow

- When the user types `/doc-sync`.
- When they ask to update the documentation after code changes.

## Context

- The project uses Markdown documentation in the root folder and the `documentation/` directory.
- List of documentation files (English):
  - [README.md](../../README.md)
  - [documentation/INDEX.md](../../documentation/INDEX.md)
  - [documentation/architecture.md](../../documentation/architecture.md)
  - [documentation/galera_bootstrap.md](../../documentation/galera_bootstrap.md)
  - [documentation/innodb_cluster.md](../../documentation/innodb_cluster.md)
  - [documentation/makefile.md](../../documentation/makefile.md)
  - [documentation/mongo_replicaset.md](../../documentation/mongo_replicaset.md)
  - [documentation/patroni_cluster.md](../../documentation/patroni_cluster.md)
  - [documentation/pg_multimaster.md](../../documentation/pg_multimaster.md)
  - [documentation/pgpool_cluster.md](../../documentation/pgpool_cluster.md)
  - [documentation/postgresql_support.md](../../documentation/postgresql_support.md)
  - [documentation/replication_setup.md](../../documentation/replication_setup.md)
  - [documentation/replication_ssl.md](../../documentation/replication_ssl.md)
  - [documentation/scripts.md](../../documentation/scripts.md)
  - [documentation/supported_products.md](../../documentation/supported_products.md)
  - [documentation/tests.md](../../documentation/tests.md)
  - [documentation/tls_setup.md](../../documentation/tls_setup.md)
- List of documentation files (French):
  - [README_fr.md](../../README_fr.md)
  - [documentation/INDEX_fr.md](../../documentation/INDEX_fr.md)
  - [documentation/innodb_cluster_fr.md](../../documentation/innodb_cluster_fr.md)
  - [documentation/makefile_fr.md](../../documentation/makefile_fr.md)
  - [documentation/mongo_replicaset_fr.md](../../documentation/mongo_replicaset_fr.md)
  - [documentation/pg_multimaster_fr.md](../../documentation/pg_multimaster_fr.md)
  - [documentation/postgresql_support_fr.md](../../documentation/postgresql_support_fr.md)
  - [documentation/supported_products_fr.md](../../documentation/supported_products_fr.md)
  - [documentation/tests_fr.md](../../documentation/tests_fr.md)

## Task

1. Identify recently modified files (via git diff or IDE history).
2. For each file, spot configuration changes, new features, or rule updates.
3. Update the corresponding sections in the relevant documentation files or `README.md`.
4. Synchronize translations if English/French files exist for the same component.
5. Propose a clear diff and wait for validation before writing.

## Constraints

- Never delete documentation sections without explicit confirmation.
- Respect the existing style (headings, lists, examples).
- If information is uncertain, ask a question instead of making it up.
- **IMPORTANT**: If new documentation files (`*.md`) are added to the repository, you MUST update this list in `doc-sync.md`.
