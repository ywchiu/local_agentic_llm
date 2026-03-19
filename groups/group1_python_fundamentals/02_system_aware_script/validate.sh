#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="02_system_aware_script"

# --- Check 1: runs_without_error ---
# Find any .py file in workspace/ and run it; check exit code 0
check1="FAIL"
py_file=$(find "$WORKSPACE" -maxdepth 1 -name '*.py' -type f | head -n 1)
if [ -n "$py_file" ]; then
    if python3 "$py_file" > /dev/null 2>&1; then
        check1="PASS"
    fi
fi
echo "${TEST_ID}|runs_without_error|${check1}"

# --- Check 2: report_generated ---
# Check that a report file exists and contains system-relevant keywords
check2="FAIL"
report_file=$(find "$WORKSPACE" -maxdepth 1 -name '*report*' -type f | head -n 1)
if [ -n "$report_file" ] && [ -s "$report_file" ]; then
    content=$(tr '[:upper:]' '[:lower:]' < "$report_file")
    matched=0
    for keyword in os cpu ram memory disk python; do
        if echo "$content" | grep -q "$keyword"; then
            matched=$((matched + 1))
        fi
    done
    # Require at least 4 of the 6 keywords (ram and memory count as alternatives)
    if [ "$matched" -ge 4 ]; then
        check2="PASS"
    fi
fi
echo "${TEST_ID}|report_generated|${check2}"

# --- Check 3: accurate_info ---
# Verify at least one value in the report matches reality:
#   - python version string appears, OR
#   - OS name from uname appears
check3="FAIL"
if [ -n "${report_file:-}" ] && [ -s "${report_file:-}" ]; then
    content=$(cat "$report_file")
    content_lower=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    # Check python version
    py_version=$(python3 --version 2>&1 | awk '{print $2}')
    if echo "$content" | grep -q "$py_version"; then
        check3="PASS"
    fi

    # Check OS name from uname
    if [ "$check3" != "PASS" ]; then
        os_name=$(uname -s)
        os_name_lower=$(echo "$os_name" | tr '[:upper:]' '[:lower:]')
        if echo "$content_lower" | grep -q "$os_name_lower"; then
            check3="PASS"
        fi
    fi

    # Also accept "darwin" or "macos" on macOS
    if [ "$check3" != "PASS" ]; then
        if echo "$content_lower" | grep -qE "darwin|macos|mac os"; then
            if [ "$(uname -s)" = "Darwin" ]; then
                check3="PASS"
            fi
        fi
    fi
fi
echo "${TEST_ID}|accurate_info|${check3}"
