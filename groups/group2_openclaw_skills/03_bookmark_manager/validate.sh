#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="03_bookmark_manager"

# Check 1: skill_structure
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        [ -n "$close_line" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: companion_script — a .sh or .py file exists alongside SKILL.md
check2=FAIL
SCRIPT_FILE=$(find "$WORKSPACE" -maxdepth 1 \( -name "*.sh" -o -name "*.py" \) -type f | head -1)
if [ -n "$SCRIPT_FILE" ]; then
    check2=PASS
fi
echo "${TEST_ID}|companion_script|${check2}"

# Check 3: json_persistence — references or creates a .json file
check3=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "\.json|json\.dump|json\.load|bookmarks.*file|save.*json"; then
    check3=PASS
fi
echo "${TEST_ID}|json_persistence|${check3}"
