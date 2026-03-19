#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="10_smart_home_controller"

# Find the Python script
PY_SCRIPT=""
for name in controller.py smart_home.py main.py run.py home.py; do
    [ -f "$WORKSPACE/$name" ] && PY_SCRIPT="$WORKSPACE/$name" && break
done
if [ -z "$PY_SCRIPT" ]; then
    PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
fi

# Check 1: skill_and_script — SKILL.md with frontmatter (declares config) + .py script
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ] && [ -n "$PY_SCRIPT" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$WORKSPACE/SKILL.md" 2>/dev/null)
    if echo "$FM" | grep -qiE "config|devices|require"; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: light_control — run "turn on living room light", check state
check2=FAIL
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" "turn on living room light" 2>/dev/null) || true

    # Find state file (anything that's not devices.json, SKILL.md, or the script)
    STATE_FILE=$(find "$WORKSPACE" -maxdepth 1 -name "*.json" ! -name "devices.json" -type f -newer "$PY_SCRIPT" 2>/dev/null | head -1)
    # Also check if devices.json was updated as state
    if [ -z "$STATE_FILE" ]; then
        STATE_FILE=$(find "$WORKSPACE" -maxdepth 1 -name "state*" -o -name "*state*" 2>/dev/null | head -1)
    fi
    if [ -z "$STATE_FILE" ]; then
        # Maybe the model uses devices.json itself as state
        STATE_FILE="$WORKSPACE/devices.json"
    fi

    if [ -f "$STATE_FILE" ] && grep -qi "on" "$STATE_FILE" 2>/dev/null; then
        check2=PASS
    fi
fi
echo "${TEST_ID}|light_control|${check2}"

# Check 3: thermostat_control — run "set bedroom temperature to 22", check state
check3=FAIL
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" "set bedroom temperature to 22" 2>/dev/null) || true

    if [ -f "${STATE_FILE:-}" ] && grep -q "22" "$STATE_FILE" 2>/dev/null; then
        check3=PASS
    fi
fi
echo "${TEST_ID}|thermostat_control|${check3}"
