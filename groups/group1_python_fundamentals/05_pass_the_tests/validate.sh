#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="05_pass_the_tests"

# Check 1: string_utils.py exists in workspace
if [ -f "$WORKSPACE/string_utils.py" ]; then
    echo "${TEST_ID}|module_exists|PASS"
else
    echo "${TEST_ID}|module_exists|FAIL"
    echo "${TEST_ID}|tests_pass|FAIL"
    echo "${TEST_ID}|all_tests_pass|FAIL"
    exit 0
fi

# Check 2 & 3: Run pytest and check results
PYTEST_OUTPUT=$(cd "$WORKSPACE" && python3 -m pytest test_string_utils.py -v 2>&1) || true

if echo "$PYTEST_OUTPUT" | grep -q "failed\|error"; then
    echo "${TEST_ID}|tests_pass|FAIL"
    echo "${TEST_ID}|all_tests_pass|FAIL"
elif echo "$PYTEST_OUTPUT" | grep -qE "[0-9]+ passed"; then
    echo "${TEST_ID}|tests_pass|PASS"

    # Check that all 15 tests passed with 0 failed
    if echo "$PYTEST_OUTPUT" | grep -qE "15 passed"; then
        echo "${TEST_ID}|all_tests_pass|PASS"
    else
        echo "${TEST_ID}|all_tests_pass|FAIL"
    fi
else
    echo "${TEST_ID}|tests_pass|FAIL"
    echo "${TEST_ID}|all_tests_pass|FAIL"
fi
