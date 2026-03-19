#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="08_api_data_dashboard"

# ── Check 1: runs_without_error ──────────────────────────────────────────────
# Find the main .py file in workspace/, run it, check exit code 0
check_name="runs_without_error"
main_py=$(find "$WORKSPACE" -maxdepth 2 -name '*.py' -type f | head -n 1)
if [ -z "$main_py" ]; then
    echo "${TEST_ID}|${check_name}|FAIL"
else
    if (cd "$WORKSPACE" && python3 "$main_py") > /dev/null 2>&1; then
        echo "${TEST_ID}|${check_name}|PASS"
    else
        echo "${TEST_ID}|${check_name}|FAIL"
    fi
fi

# ── Check 2: dashboard_generated ─────────────────────────────────────────────
# Check that dashboard.html exists and contains expected HTML markers
check_name="dashboard_generated"
dashboard="$WORKSPACE/dashboard.html"
if [ -f "$dashboard" ]; then
    if grep -qiE '<html|<table|<img|plotly' "$dashboard"; then
        echo "${TEST_ID}|${check_name}|PASS"
    else
        echo "${TEST_ID}|${check_name}|FAIL"
    fi
else
    echo "${TEST_ID}|${check_name}|FAIL"
fi

# ── Check 3: has_chart_and_data ──────────────────────────────────────────────
# Check that dashboard.html contains at least 2 of 3 known user names AND
# contains either an embedded image or plotly/chart div
check_name="has_chart_and_data"
if [ ! -f "$dashboard" ]; then
    echo "${TEST_ID}|${check_name}|FAIL"
else
    # Count how many of the known user names appear
    name_count=0
    grep -qi 'Leanne Graham' "$dashboard" && name_count=$((name_count + 1))
    grep -qi 'Ervin Howell' "$dashboard" && name_count=$((name_count + 1))
    grep -qi 'Clementine Bauch' "$dashboard" && name_count=$((name_count + 1))

    has_names=false
    if [ "$name_count" -ge 2 ]; then
        has_names=true
    fi

    # Check for embedded chart: base64 image, .png reference, or plotly div
    has_chart=false
    if grep -qiE 'data:image/png;base64|\.png|plotly|<canvas|chart-container|<svg' "$dashboard"; then
        has_chart=true
    fi

    if $has_names && $has_chart; then
        echo "${TEST_ID}|${check_name}|PASS"
    else
        echo "${TEST_ID}|${check_name}|FAIL"
    fi
fi
