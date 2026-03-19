#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="04_weather_lookup"

SKILL_FILE="$WORKSPACE/SKILL.md"

# Check 1: env_var_declared — frontmatter declares an API key env var
check1=FAIL
if [ -f "$SKILL_FILE" ]; then
    # Extract frontmatter (between first and second ---)
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    if echo "$FM" | grep -qiE "api.?key|WEATHER|requires.*env|env.*:"; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|env_var_declared|${check1}"

# Check 2: api_integration — skill or script uses curl with a weather API
check2=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "curl.*weather|weather.*api|openweathermap|wttr\.in|weatherapi"; then
    check2=PASS
fi
echo "${TEST_ID}|api_integration|${check2}"

# Check 3: bins_declared — frontmatter declares curl as required
check3=FAIL
if [ -f "$SKILL_FILE" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    if echo "$FM" | grep -qiE "bins.*curl|curl|requires.*bins"; then
        check3=PASS
    fi
fi
echo "${TEST_ID}|bins_declared|${check3}"
