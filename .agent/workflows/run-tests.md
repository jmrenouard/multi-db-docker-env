---
description: run-tests
---

# Run Tests Workflow

This workflow automates the execution of data integrity and performance tests, followed by documentation synchronization.

## When to use this workflow

- When the user types `/run-tests`.
- When changes are made to the database scripts or test queries.
- Before a release or after data injection.

## Task

// turbo

1. Execute all tests using the Makefile.

   ```bash
   make test-all
   ```

2. If tests pass, trigger documentation synchronization.

   ```bash
   /doc-sync
   ```

## Constraints

- Stop if any test fails and report the error.
- Ensure the MariaDB container is running before starting.
