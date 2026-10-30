---
trigger: always_on
description: Mandatory Multi-DB Docker Environment project governance — systematic update of Action Logbook (docs/ACTION_LOGBOOK.md) and RCA Register (docs/RCA_REGISTER.md) on every request, change, and result.
---

# Project Rule: Systematic Update of Action Logbook and RCA Register

For **every user request, every change, and every result** on the **Multi-DB Docker Environment** project, you **MUST MANDATORILY** update the following two living registers in English before closing the task:

## 1. Action Logbook (`docs/ACTION_LOGBOOK.md`)

Must be updated on **every request**, **every change**, and **every result**:
- **Ongoing Actions (`IN PROGRESS`)**: Record every new request as soon as work begins (`ACT-XXX`, date/time, Issue `#<id>`, branch, **Request**).
- **Completed Actions (`COMPLETED`)**: Once verified, record **Request**, **Changes**, and **Result** (test suite output, PR diff size `< 15,000`, Issue `#<id>`, PR `#<pr>`, commit).

## 2. RCA & Technical Transparency Register (`docs/RCA_REGISTER.md`)

Must be updated on **every request**, **every change**, and **every result** across its 4 sections:
1. **Errors & Bugs Encountered (`RCA-XXX`)**: Observed Symptom, Root Cause Analysis (RCA), Applied Change / Fix, and Result & Non-Regression Test.
2. **Technical Dead-Ends & Abandoned Leads (`IMP-XXX`)**: Explored and abandoned paths with technical/security justification.
3. **Current Approximations & Simplifying Assumptions (`APP-XXX`)**: Simplifications, heuristics, or laboratory mocks, trade-offs, and removal condition.
4. **Unimplemented Ideas & Future Roadmap (`IDEA-XXX`)**: New database versions, high-availability targets, and engineering improvements identified for the roadmap.

> **Strict Prohibition**: Never declare a request finished or merge a PR without updating `docs/ACTION_LOGBOOK.md` and `docs/RCA_REGISTER.md`.
