---
trigger: explicit_call
description: Pre-flight checks before releasing
category: tool
---

# Release Preflight Workflow

Ensure consistency across versioning artifacts before cutting a release.

## 1. Extract Versions

```bash
# 1. VERSION file
TXT_VER=$(cat VERSION)

# 2. Changelog latest version
LOG_VER=$(head -n 1 Changelog | awk '{print $1}')
```

## 2. Validate Consistency

Both versions must match.

```bash
if [ "$TXT_VER" == "$LOG_VER" ]; then
    echo "SUCCESS: Versions match ($TXT_VER)."
else
    echo "FAIL: Version Mismatch!"
    echo "Txt (VERSION):   $TXT_VER"
    echo "Changelog:       $LOG_VER"
    exit 1
fi
```

## 3. Smoke Test

Run the configuration and environment validation suite.

```bash
# Verify environment and configuration integrity
make verify
```

## 4. Proceed to Release

If all checks pass, proceed with tagging and pushing (or `/git-flow` if implemented).
