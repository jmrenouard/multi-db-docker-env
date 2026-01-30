---
trigger: explicit_call
description: Inject reference datasets (employees, sakila) into active database instances.
category: skill
---
# Data Injection

## 🧠 Rationale

Testing requires realistic data structures. Automating the injection of standard benchmarks ensures consistency across different database engines and versions.

## 🛠️ Implementation

- **Generic Injection**: `make inject-data service=<service> db=<employees|sakila>`.
- **Shortcut**: `make inject-employees` (auto-detects active environment).
- **Shortcut**: `make inject-sakila`.

## ✅ Verification

- Run `SELECT COUNT(*) FROM ...` on injected tables.
- Use `make info` to see the active service being targeted.
