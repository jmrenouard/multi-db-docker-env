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
  - [README.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/README.md)
  - [documentation/architecture.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/architecture.md)
  - [documentation/galera_bootstrap.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/galera_bootstrap.md)
  - [documentation/makefile.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/makefile.md)
  - [documentation/scripts.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/scripts.md)
  - [documentation/tests.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/tests.md)
  - [documentation/replication_setup.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/replication_setup.md)
- List of documentation files (French):
  - [README.fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/README.fr.md)
  - [documentation/architecture_fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/architecture_fr.md)
  - [documentation/galera_bootstrap_fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/galera_bootstrap_fr.md)
  - [documentation/makefile_fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/makefile_fr.md)
  - [documentation/scripts_fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/scripts_fr.md)
  - [documentation/tests_fr.md](file:///home/jmren/GIT_REPOS/multi-db-docker-env/documentation/tests_fr.md)

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
