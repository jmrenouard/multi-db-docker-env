---
trigger: always_on
description: The absolute source of truth and project constitution
category: governance
---
# 00 Constitution: Project Foundation

## 🧠 Rationale

This document constitutes the unique and absolute source of truth for the project. Its prior consultation is imperative before any technical intervention to maintain architectural integrity and operational consistency.

## 🛠️ Implementation

### 1. Fundamental Principles ($$SYSTEM_CRITICAL$$)

- **Primary Goal**: Rapidly setup different types of databases to demonstrate proofs of concept (PoC) for database architectures and configure viable solutions for production environments.
- **Modularity**: The environment must remain modular, allowing on-demand DB version switching.
- **Orchestration**: `Makefile` is the EXCLUSIVE entry point for all operations.
- **Transparency**: All routing must pass through the Traefik reverse proxy for single-port access (`3306`).
- **Standardization**: All governance assets must follow the Agent-Friendly Format (AFF).

### 2. Operational Authority

- The Agent must strictly adhere to the rules defined in `.agent/rules/`.
- The `go-agent` workflow acts as the super manager orchestrator for all structural and strategic changes.
- Contradictions must be resolved by prioritizing these rules over any other documentation.

## ✅ Verification

- Run `/compliance-sentinel` to audit compliance with these principles.
