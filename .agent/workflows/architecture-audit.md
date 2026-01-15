---
description: archi
---

# Architecture Audit Workflow

This workflow performs a structural audit of the codebase to identify inconsistencies, naming issues, and consolidation opportunities.

## When to use this workflow

- When the user types `/audit`.
- Before a major refactoring phase.
- To ensure compliance with `ARCHITECTURE.md`.

## Task

1. **Analyze Naming & Semantics**:
   - Check verbs used in `Makefile` targets (ensure consistency: e.g., using `start/stop` vs `up/down`).
   - Check script naming in `scripts/` (ensure standardized prefixing or categorization).

2. **Parameter Consistency**:
   - Audit variable names across `Makefile`, `scripts/test_runner.sh`, and `scripts/verify_data.sh` (e.g., `CONTAINER_NAME` vs `DB_CONTAINER`).

3. **Code Consolidation**:
   - Identify redundant logic between `test_runner.sh` and `verify_data.sh`.
   - Propose "Generic Wrappers" to replace duplicated Docker execution commands.

4. **Output Report**:
   - Generate a "Structural Health Report" highlighting:
     - **Semantic Drift**: Inconsistent naming or verbs.
     - **Redundancy**: Blocks of code that could be merged.
     - **Refactoring Proposals**: Specific steps to centralize configuration.

## Constraints

- Respect the `$$IMMUTABLE$$` sections of `ARCHITECTURE.md`.
- Focus on Bash and Makefile logic as per `CONSTRAINTS.md`.
- Proposals must be purely technical and actionable.
