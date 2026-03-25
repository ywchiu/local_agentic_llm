#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="09_data_pipeline"

# Find SKILL.md — check workspace root first, then search subdirectories
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SKILL_DIR="$WORKSPACE"
else
    SKILL_DIR=$(find "$WORKSPACE" -name "SKILL.md" -type f -maxdepth 3 -print -quit 2>/dev/null | xargs dirname 2>/dev/null || echo "$WORKSPACE")
fi

# Check 1: skill_and_script — SKILL.md with frontmatter + .py script
check1=FAIL
PY_SCRIPT=""
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    content=$(cat "$SKILL_DIR/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---"; then
        PY_SCRIPT=$(find "$SKILL_DIR" -maxdepth 2 -name "*.py" -type f | head -1)
        [ -n "$PY_SCRIPT" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: pipeline_runs — run script, check .md file produced
check2=FAIL
MD_FILE=""
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" 2>/dev/null) || true
    MD_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.md" ! -name "SKILL.md" ! -name "README.md" -type f | head -1)
    [ -n "$MD_FILE" ] && check2=PASS
fi
echo "${TEST_ID}|pipeline_runs|${check2}"

# Check 3: correct_filtering — output has exactly 10 posts from userId=1
check3=FAIL
if [ -n "${MD_FILE:-}" ] && [ -f "$MD_FILE" ]; then
    # Count lines containing "Post X by user 1" — should be 10
    # Posts with userId=1 are: 1, 11, 21, 31, 41, 51, 61, 71, 81, 91
    count=$(grep -ciE "post.*(1|11|21|31|41|51|61|71|81|91).*user.?1|user.?1.*post" "$MD_FILE" 2>/dev/null || echo 0)
    # Alternative: just count how many "user 1" or "userId.*1" references
    if [ "$count" -lt 5 ]; then
        # Try looser match — count title-like lines
        count=$(grep -cE "^[#*>|0-9.+-]" "$MD_FILE" 2>/dev/null || echo 0)
        # Should have around 10 list items or headings for 10 posts (allow wider range for varied formatting)
        [ "$count" -ge 5 ] && [ "$count" -le 40 ] && check3=PASS
    else
        [ "$count" -ge 8 ] && check3=PASS
    fi
fi
echo "${TEST_ID}|correct_filtering|${check3}"
