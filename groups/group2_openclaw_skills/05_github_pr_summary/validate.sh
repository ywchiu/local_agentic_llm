#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="05_github_pr_summary"

# Find SKILL.md — check workspace root first, then search subdirectories
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SKILL_DIR="$WORKSPACE"
else
    SKILL_DIR=$(find "$WORKSPACE" -name "SKILL.md" -type f -maxdepth 3 -print -quit 2>/dev/null | xargs dirname 2>/dev/null || echo "$WORKSPACE")
fi

SKILL_FILE="$SKILL_DIR/SKILL.md"

# Check 1: declares_dependencies — frontmatter declares both gh binary AND GITHUB_TOKEN env var
check1=FAIL
if [ -f "$SKILL_FILE" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    has_gh=$(echo "$FM" | grep -ciE "bins.*gh|gh|requires.*bins" || true)
    has_token=$(echo "$FM" | grep -ciE "GITHUB_TOKEN|github.*token|env.*GITHUB|requires.*env" || true)
    if [ "$has_gh" -gt 0 ] && [ "$has_token" -gt 0 ]; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|declares_dependencies|${check1}"

# Check 2: gh_commands — contains gh pr list or equivalent
check2=FAIL
ALL_CONTENT=$(cat "$SKILL_DIR"/*.md "$SKILL_DIR"/*.sh "$SKILL_DIR"/*.py "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null | sort -u || true)
if echo "$ALL_CONTENT" | grep -qiE "gh pr list|gh pr view|gh api.*pulls"; then
    check2=PASS
fi
echo "${TEST_ID}|gh_commands|${check2}"

# Check 3: summary_format — references title, author, age/date
check3=FAIL
matches=0
echo "$ALL_CONTENT" | grep -qiE "title" && matches=$((matches+1))
echo "$ALL_CONTENT" | grep -qiE "author|creator|user" && matches=$((matches+1))
echo "$ALL_CONTENT" | grep -qiE "age|date|created|days|old|time" && matches=$((matches+1))
if [ "$matches" -ge 3 ]; then
    check3=PASS
fi
echo "${TEST_ID}|summary_format|${check3}"
