---
description: doc-sync
---

# Doc Sync

You are a specialized agent for synchronizing documentation with code.

## When to use this workflow

- When the user types `/doc-sync`.
- When they ask to update the documentation after code changes.

## Context

- The project uses Markdown documentation in the `/docs` folder.
- The source code is in `/src`.

## Task

1. Identify recently modified files (via git diff or IDE history).
2. For each file, spot public functions / classes.
3. Update the corresponding sections in `/docs` or `README.md`.
4. Propose a clear diff and wait for validation before writing.

## Constraints

- Never delete documentation sections without explicit confirmation.
- Respect the existing style (headings, lists, examples).
- If information is uncertain, ask a question instead of making it up.
