#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="02_fix_broken_skill"

# Find SKILL.md — check workspace root first, then search subdirectories
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SKILL_DIR="$WORKSPACE"
else
    SKILL_DIR=$(find "$WORKSPACE" -name "SKILL.md" -type f -maxdepth 3 -print -quit 2>/dev/null | xargs dirname 2>/dev/null || echo "$WORKSPACE")
fi

# Check 1: skill_structure — SKILL.md now has valid frontmatter with name + description + closing ---
check1=FAIL
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    content=$(cat "$SKILL_DIR/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        if [ -n "$close_line" ]; then
            check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: script_fixed — run.sh executes without error
check2=FAIL
if [ -f "$SKILL_DIR/run.sh" ]; then
    chmod +x "$SKILL_DIR/run.sh" 2>/dev/null
    if bash "$SKILL_DIR/run.sh" "TestUser" > /dev/null 2>&1; then
        check2=PASS
    fi
fi
echo "${TEST_ID}|script_fixed|${check2}"

# Check 3: preserves_intent — still a greeting skill
check3=FAIL
ALL_CONTENT=$(cat "$SKILL_DIR/SKILL.md" "$SKILL_DIR/run.sh" 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "greet|hello|welcome"; then
    check3=PASS
fi
echo "${TEST_ID}|preserves_intent|${check3}"
