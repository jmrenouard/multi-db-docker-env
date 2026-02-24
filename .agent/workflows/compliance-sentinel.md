---
trigger: always_on
description: Automated audit to enforce project constitution rules
category: governance
---

# Compliance Sentinel

This workflow acts as a static analysis guardrail to ensure "Constitution" compliance.

## 1. Core Check: Makefile Architecture

Ensure the `Makefile` remains the exclusive entry point and exists in the root directory.

```bash
if [ ! -f "Makefile" ]; then
  echo "FAIL: Makefile is missing. Architecture must rely on a Makefile."
  exit 1
fi
```

## 2. Core Check: Bash Robustness

Verify that shell scripts use `set -euo pipefail`.

```bash
# Check if scripts in the project use strict bash settings
grep -rL "^set -euo pipefail" scripts/ tests/ build/ | grep "\.sh$" || true
echo "Review the above scripts to ensure they use set -euo pipefail"
```

## 3. Core Check: Docker Compose Presence

Ensure `docker-compose.yml` or `docker-compose.yaml` exists for orchestration.

```bash
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
  echo "FAIL: docker-compose configuration is missing."
  exit 1
fi
```

## 4. Changelog Compliance

Verify the format of the latest Changelog entries.

```bash
head -n 20 Changelog
# Must follow:
# X.Y.Z YYYY-MM-DD
# - type: description
```

## 5. Execution

Run these checks before any major commit or release.
