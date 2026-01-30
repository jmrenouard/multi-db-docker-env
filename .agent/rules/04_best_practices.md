---
trigger: always_on
description: Advanced shell scripting and Docker best practices
category: governance
---
# 04 Best Practices: Robustness & Portability

## 🧠 Rationale

Consistency in script execution and container management is the foundation of a reliable testing laboratory.

## 🛠️ Implementation

### Bash Scripting standards

- Always use `set -euo pipefail` to ensure scripts exit on any error.
- Quote all variables to prevent word splitting and globbing.
- Use `[[ ]]` for conditional tests instead of `[ ]`.
- Prefer `command -v` over `which` for checking tool existence.

### Docker & Container Management

- Ensure clean startup/shutdown via `docker compose down -v` to reset state between tests.
- Use healthchecks in `docker-compose.yaml` to wait for database readiness.
- Minimize image layer count while maintaining readability.

### Test Automation

- Tests should be easy to run from scratch.
- Tests should be reproducible and scripted.
- Tests should be run on specific features easily.

## ✅ Verification

- Audit scripts for `set -euo pipefail`.
- Run `make test-all` for full suite validation.
