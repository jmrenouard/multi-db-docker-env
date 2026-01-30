---
trigger: explicit_call
description: Systematic problem analysis and ideation
category: tool
---

# Ideation Workflow

This workflow analyzes the project structure, performance reports, and objectives to suggest actionable improvements and new features.

## When to use this workflow

- When the user types `/ideate`.
- When the project reaches a milestone and needs fresh directions.

## Task

1. Analyze current project state:
   - Review `OBJECTIVES.md` and `ARCHITECTURE.md`.
   - Check `reports/performance_report.md` for bottlenecks.
   - Scan `scripts/` for missing automation opportunities.

2. Generate 3 to 4 technical evolution paths:
   - One focusing on **Performance/Optimization** (e.g., indexing, partitioning).
   - One focusing on **Automation/DX** (e.g., CI/CD, better reporting).
   - One focusing on **Features/Testing** (e.g., Chaos engineering, data masking).
   - One focusing on **Observability/UI** (e.g., Grafana dashboards, enhanced HTML reports).

3. Present ideas with:
   - **Title**: A clear name for the feature.
   - **Rationale**: Why it matters.
   - **Complexity**: Low/Medium/High.
   - **Impact**: Expected benefit.

## Constraints

- Suggestions must respect `CONSTRAINTS.md` (no external languages besides Bash/Python, MariaDB focus).
- Avoid generic advice; link to specific files or metrics in the repo.
