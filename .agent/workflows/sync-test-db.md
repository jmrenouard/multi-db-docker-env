---
description: Synchronize test_db subdirectory with remote master branch
---

# 🔄 Sync test_db Workflow

This workflow ensures that the `test_db` subcommittee is linked to [jmrenouard/test_db](https://github.com/jmrenouard/test_db) and is up to date with the `master` branch.

## Steps

1. **Verify Submodule Connection**
   - Check if `.gitmodules` points to the correct repository.
   - Run `git submodule status` to check the current commit.

2. **Synchronize from Remote**
   - Run `make sync-test-db` to pull the latest changes from the master branch.

3. **Verify Integrity**
   - Check if `test_db/employees.sql` exists and is accessible.
   - Run a config test to ensure no paths are broken: `make test-config`.

// turbo
4. Run synchronization
`make sync-test-db`
