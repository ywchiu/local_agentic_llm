#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="01_pomodoro_timer"

# Find SKILL.md — check workspace root first, then search subdirectories
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SKILL_DIR="$WORKSPACE"
else
    SKILL_DIR=$(find "$WORKSPACE" -name "SKILL.md" -type f -maxdepth 3 -print -quit 2>/dev/null | xargs dirname 2>/dev/null || echo "$WORKSPACE")
fi

# Check 1: skill_structure — SKILL.md with valid frontmatter (name + description)
check1=FAIL
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    content=$(cat "$SKILL_DIR/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        # Check closing --- and body after it
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        if [ -n "$close_line" ]; then
            body=$(echo "$content" | tail -n +"$((close_line + 1))" | tr -d '[:space:]')
            [ -n "$body" ] && check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: has_timer_logic — mentions timer/pomodoro concepts
check2=FAIL
ALL_CONTENT=$(cat "$SKILL_DIR"/*.md "$SKILL_DIR"/*.sh "$SKILL_DIR"/*.py "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null | sort -u || true)
if echo "$ALL_CONTENT" | grep -qiE "timer|pomodoro|countdown|minutes|duration|25.*min|start.*session|stop.*session"; then
    check2=PASS
fi
echo "${TEST_ID}|has_timer_logic|${check2}"

# Check 3: session_logging — writes sessions to a log/file
check3=FAIL
if echo "$ALL_CONTENT" | grep -qiE "log|\.txt|\.csv|\.json|write.*file|append|completed.*session|session.*record"; then
    check3=PASS
fi
echo "${TEST_ID}|session_logging|${check3}"
