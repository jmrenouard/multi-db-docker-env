---
trigger: explicit_call
description: Automate git-flow release process
category: tool
---

# Git-Flow Release Workflow

## 1. Pre-flight Consistency Check

Verify that `Changelog` and `VERSION` are synchronized.

```bash
git status --porcelain
CURRENT_VER=$(cat VERSION | tr -d '[:space:]')
CHANGELOG_VER=$(head -n 1 Changelog | awk '{print $1}')

echo "Checking version consistency: $CURRENT_VER"

if [ "$CURRENT_VER" != "$CHANGELOG_VER" ]; then
    echo "ERROR: VERSION ($CURRENT_VER) does not match Changelog ($CHANGELOG_VER)"
    exit 1
fi

echo "Consistency check passed."
```

// turbo

## 2. Commit Current Changes

Commit all pending changes (documentation, configuration) for the current version.

```bash
git add .
# Only commit if there are changes
if ! git diff --cached --quiet; then
    git commit -m "feat: release $CURRENT_VER"
fi
```

// turbo

## 3. Create Tag

Extract the latest release notes and create an annotated tag.

```bash
# Extract content from the first version header until the next one
TAG_MSG=$(awk "/^$CURRENT_VER/,/^([0-9]+\.[0-9]+\.[0-9]+)/ {if (\$0 !~ /^([0-9]+\.[0-9]+\.[0-9]+)/) print}" Changelog | sed '/^$/d')
git tag -a v$CURRENT_VER -m "Release $CURRENT_VER" -m "$TAG_MSG"
```

// turbo

## 4. Push Branch and Tag

Push to the remote repository.

```bash
git push origin main
git push origin v$CURRENT_VER --force
```

// turbo

## 5. Post-Verification: Initialize Next Cycle

> [!WARNING]
> This phase MUST be executed ONLY AFTER verifying the remote release state.

Calculate the next patch version and update files for the next development cycle.

```bash
NEW_VER=$(echo $CURRENT_VER | awk -F. '{print $1"."$2"."($3+1)}')
echo $NEW_VER >| VERSION

DATE=$(date +%Y-%m-%d)
echo -e "$NEW_VER $DATE\n\n- \n" >| tmp_changelog && cat Changelog >> tmp_changelog && mv tmp_changelog Changelog
```

// turbo

## 6. Commit Version Bump

Commit the incremented version.

```bash
git add VERSION Changelog
git commit -m "chore: bump version to $NEW_VER"
git push origin main
```

// turbo
