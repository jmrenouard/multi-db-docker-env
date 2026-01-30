---
trigger: explicit_call
description: Super manager orchestrator for coordinating governance, skills, and workflows.
category: tool
---

# Go-Agent (The Super Manager)

## 🧠 Rationale

High-density development requires a "Super Manager" capable of synthesizing project state, coordinating specialized workflows, and enforcing architectural integrity across multiple domains (Tests, Docs, Security).

## 🛠️ Implementation

### 1. Orchestration Protocol

The `go-agent` workflow coordinates the following phases:

1. **State Audit**:
    - Invoke `/compliance-sentinel` to verify current state.
    - Audit `Changelog` and `VERSION` for synchronization.
2. **Strategic Planning**:
    - Use `/ideate` for complex architectural changes.
    - Use `/hey-agent` to update rules/skills based on new findings.
3. **Execution & Validation**:
    - Trigger relevant implementation workflows.
    - Execute `/run-tests` or `make verify` for tier-based validation.
4. **Documentation Synchronization**:
    - Execute `/doc-sync` to ensure bilingual parity.
5. **Final Quality Gate**:
    - Review `walkthrough.md` against initial goals.
    - Proceed with `/git-flow` for release management.

### 2. Decision Matrix

| Trigger | Primary Sub-Workflow | Coordination Goal |
| :--- | :--- | :--- |
| Structural Change | `/hey-agent` | Update governance and AFF assets |
| Performance Issue | `/run-tests` | Generate HTML reports and audit regressions |
| Localization Gap | `/doc-sync` | Mirror English/French technical docs |
| Release Staging | `/release-preflight` | Ensure 100% QA before tagging |

## ✅ Verification

- Validate the workflow file exists in `.agent/workflows/go-agent.md`.
- Ensure frontend metadata (AFF) is correctly parsed by the agent.
- Audit for overlaps or contradictions with `/hey-agent`.
