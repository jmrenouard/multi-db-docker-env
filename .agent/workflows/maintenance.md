---
trigger: explicit_call
description: Project maintenance and housekeeping tasks
category: tool
---

# Maintenance Workflow

This workflow performs routine cleanup and health checks on the development environment.

## When to use this workflow

- When the user types `/maintain`.
- Before starting a new feature or after finishing tests.
- To troubleshoot environment issues.

## Task

// turbo

1. Clean up generated reports and temporary files.

   ```bash
   make clean
   ```

2. Check the status of the MariaDB container.

   ```bash
   make status
   ```

3. Verify if the employees dataset is correctly loaded.

   ```bash
   make verify
   ```

## Constraints

- If `make status` shows the container is down, try to start it with `make start`.
- Report any inconsistencies found during `make verify`.
