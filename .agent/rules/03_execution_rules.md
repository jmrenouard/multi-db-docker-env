---
trigger: always_on
description: Strict execution constraints and development workflow
category: governance
---
# 03 Execution Rules: Safeguards and Workflow

## 🧠 Rationale

High-density development requires strict guardrails to prevent regressions and maintain operational silence while ensuring all changes are verified and documented.

## 🛠️ Implementation

### 1. Formal Prohibitions (Hard Constraints)

1. **NON-REGRESSION**: Deleting existing code is PROHIBITED without relocation or commenting out.
2. **DEPENDENCY MINIMALISM**: No new dependencies in containers unless absolutely necessary.
3. **OPERATIONAL SILENCE**: Explanations/pedagogy are PROSCRIBED. Only code, commands, and results.
4. **LANGUAGE**: Implementation limited to Bash and Docker.
5. **DOCUMENTATION**: All comments and documentation within code and configuration files MUST be in English ONLY.

### 2. Output Format

1. **NO CHATTER**: No intro or conclusion sentences.
2. **CODE ONLY**: Use Search/Replace blocks for files > 50 lines.
3. **MANDATORY PROSPECTIVE**: Conclude with 3 technical evolution paths.
4. **MEMORY UPDATE**: Include the JSON MEMORY_UPDATE_PROTOCOL block at the end.

### 3. Development Workflow

1. **Impact Analysis**: Silent analysis of consistency before generation.
2. **Bash Robustness**: `set -euo pipefail`, variable protection `"$VAR"`, explicit error handling.
3. **Validation by Proof**: Changes must be verifiable via `make test-*`. HTML reports required for documentation.
4. **Git Protocol**: Commit immediately after validation using Conventional Commits. Single branch (`main`).

### 4. Security (Lab Context)

- Embedding sensitive data (e.g., default passwords like `rootpass`) is ALLOWED for this lab environment (must be documented in README).

## ✅ Verification

- Run `make test` after any core change.
- Verify commit history follows Conventional Commits.
- Audit output for prohibited pedagogy.
