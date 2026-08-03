#!/usr/bin/env bash
# fix_issue.sh — Full GitHub Issue Fix Workflow
# Usage: bash scripts/fix_issue.sh <github-issue-url> [--dry-run]
set -euo pipefail

GH_TOKEN="${GH_TOKEN:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_BRANCH="main"
DRY_RUN=false
ISSUE_URL=""

for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    elif [[ -z "$ISSUE_URL" ]]; then
        ISSUE_URL="$arg"
    fi
done

step() { echo -e "\n=== $* ==="; }
ok()   { echo "[OK]   $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

step "1/8 - Parse Issue URL & Authentication"
[[ -z "$GH_TOKEN" ]] && fail "GH_TOKEN environment variable must be set for GitHub API access"
[[ -z "$ISSUE_URL" ]] && fail "Usage: $0 [--dry-run] <github-issue-url>"
if [[ "$ISSUE_URL" =~ github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO_NAME="${BASH_REMATCH[2]}"; ISSUE_NUMBER="${BASH_REMATCH[3]}"
    REPO="${OWNER}/${REPO_NAME}"
else
    fail "Cannot parse: $ISSUE_URL"
fi
echo "Repo: $REPO  Issue: #$ISSUE_NUMBER"

step "2/8 - Fetch Issue Details"
ISSUE_JSON=$(curl -sf -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/${REPO}/issues/${ISSUE_NUMBER}")
ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
SLUG=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--*/-/g;s/^-//;s/-$//' | cut -c1-50)
BRANCH="fix/issue-${ISSUE_NUMBER}-${SLUG}"
echo "Title : $ISSUE_TITLE"
echo "Branch: $BRANCH"

step "3/8 - Create Branch"
cd "$REPO_ROOT"
git fetch origin "$BASE_BRANCH" -q
git checkout "$BASE_BRANCH" -q
git pull origin "$BASE_BRANCH" -q
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    warn "Branch '$BRANCH' exists — switching"; git checkout "$BRANCH" -q
else
    git checkout -b "$BRANCH" -q; ok "Created: $BRANCH"
fi

step "4/8 - Apply Fix"
case "$ISSUE_NUMBER" in
    2) bash "$REPO_ROOT/scripts/apply_fix_2.sh" ;;
    *) fail "No fix handler for issue #$ISSUE_NUMBER — add apply_fix_N.sh" ;;
esac

step "5/8 - Run Tests"
bash "$REPO_ROOT/tests/test_secure_password.sh" || fail "Tests failed — aborting."

step "6/8 - Commit and Push"
git add \
    tests/test_lab.py \
    scripts/setup_repli.sh \
    scripts/run_mysqltuner.sh \
    scripts/start_mariadb.sh \
    tests/test_secure_password.sh \
    scripts/apply_fix_2.sh \
    scripts/fix_issue.sh 2>/dev/null || true
git status --short

if $DRY_RUN; then
    warn "DRY RUN — skipping commit and push"
else
    git commit -m "fix: use MYSQL_PWD env var instead of -p CLI arg (issue #${ISSUE_NUMBER})

Fixes #${ISSUE_NUMBER}: ${ISSUE_TITLE}

- tests/test_lab.py: pass password via MYSQL_PWD env var in run_mysql_query()
- scripts/setup_repli.sh: replace -p\$PASS with MYSQL_PWD prefix
- scripts/run_mysqltuner.sh: replace -p\"\$DB_PASS\" with MYSQL_PWD prefix
- scripts/start_mariadb.sh: replace conditional -p arg with MYSQL_PWD
- tests/test_secure_password.sh: new security regression test suite
- scripts/apply_fix_2.sh: automated fix script for issue #2
- scripts/fix_issue.sh: generic issue-fix workflow script"
    GH_TOKEN="$GH_TOKEN" git push -u origin "$BRANCH"
    ok "Pushed: $BRANCH"
fi

step "7/8 - Create Pull Request"
if $DRY_RUN; then warn "DRY RUN — skipping PR"; exit 0; fi

PR_JSON=$(python3 -c "
import json
title = 'fix: use MYSQL_PWD env var instead of -p CLI arg (issue #${ISSUE_NUMBER})'
body  = 'Fixes #${ISSUE_NUMBER}: ${ISSUE_TITLE}\n\nReplaces all \`-p<password>\` CLI args with \`MYSQL_PWD\` env var.\n\nCloses #${ISSUE_NUMBER}'
print(json.dumps({'title': title, 'body': body, 'head': '${BRANCH}', 'base': '${BASE_BRANCH}'}))
")

PR_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/pulls" \
    -d "$PR_JSON")

PR_NUMBER=$(echo "$PR_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['number'])")
PR_URL=$(echo "$PR_RESPONSE"    | python3 -c "import sys,json; print(json.load(sys.stdin)['html_url'])")
ok "PR #$PR_NUMBER created: $PR_URL"

step "8/8 - Merge PR"
MERGE_JSON=$(python3 -c "
import json
print(json.dumps({'commit_title': 'Merge PR #${PR_NUMBER}: fix issue #${ISSUE_NUMBER}', 'merge_method': 'merge'}))
")

MERGE=$(curl -sf -X PUT \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/merge" \
    -d "$MERGE_JSON")

SHA=$(echo "$MERGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha','N/A'))")
ok "PR #$PR_NUMBER merged! SHA: $SHA"

echo ""
echo "Done! Issue #${ISSUE_NUMBER} workflow complete."
echo "  Branch : $BRANCH"
echo "  PR URL : $PR_URL"
echo "  SHA    : $SHA"
