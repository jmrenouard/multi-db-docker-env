---
trigger: always_on
description: Changelog maintenance and memory management protocols
category: governance
---
# 05 Memory Protocol: State Management & Versioning

## 🧠 Rationale

Maintaining a clear, versioned history of changes allows for consistent context synchronization and prevents state drift over long sessions.

## 🛠️ Implementation

### 1. Changelog Maintenance

- All changes MUST be traced and documented inside `@Changelog`.
- Add new entries to the TOP of the Changelog after successful testing.
- Format: `X.Y.Z YYYY-MM-DD` followed by bullets (`- type: description`).
- **Entry Ordering**: Within a version block, entries MUST be ordered by priority:
    1. `feat:` (New features)
    2. `fix:` (Bug fixes)
    3. `doc:` (Documentation changes)
    4. `ci:` (Continuous Integration updates)
    5. Others (e.g., `refactor:`, `chore:`, `test:`, `update:`)

### 2. Versioning Logic

- Use `X.X.Y` format.
- Increment `Y` for minor actions.
- Increment `Z` (X.Z.X) for major functions and missing features.

### 3. Context & Git Sync

- Consult `git log -n 15` before starting work to synchronize context.
- Commit immediately after test and validation.
- Add a specific tag related to the `@Changelog` entry.

### 4. Rotation (FIFO)

- Max 600 lines for the active history buffer.
- Remove oldest entries exceeding the limit.

## ✅ Verification

- Check `Changelog` for correct ordering (newest at top).
- Verify tag presence after commits.
- Audit history length.

### History Entry Example

```markdown
1.0.9 2026-01-16
- chore: migrate HISTORY.md into Changelog and remove HISTORY.md.
```
