#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="01_simple_select"
DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous database
rm -f "$DB_PATH"

# Create the SQLite database from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script in workspace
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "${TEST_ID}|script_runs|FAIL"
    echo "${TEST_ID}|select_all|FAIL"
    echo "${TEST_ID}|filter_department|FAIL"
    exit 0
fi

# Check 1: script_runs - Script exists and runs without error
OUTPUT=$(python3 "$PY_SCRIPT" "Show me all employees" "$DB_PATH" 2>&1)
if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
    echo "${TEST_ID}|script_runs|PASS"
else
    echo "${TEST_ID}|script_runs|FAIL"
    echo "${TEST_ID}|select_all|FAIL"
    echo "${TEST_ID}|filter_department|FAIL"
    exit 0
fi

# Check 2: select_all - "Show me all employees" returns all 10 rows
# Count lines that contain employee names (there are 10 employees)
MATCH_COUNT=0
for name in "Alice Johnson" "Bob Smith" "Carol Williams" "David Brown" "Eva Martinez" "Frank Lee" "Grace Kim" "Henry Chen" "Irene Davis" "Jack Wilson"; do
    if echo "$OUTPUT" | grep -qi "$name"; then
        MATCH_COUNT=$((MATCH_COUNT + 1))
    fi
done

if [ "$MATCH_COUNT" -eq 10 ]; then
    echo "${TEST_ID}|select_all|PASS"
else
    echo "${TEST_ID}|select_all|FAIL"
fi

# Check 3: filter_department - "List employees in the Engineering department" returns correct subset
OUTPUT2=$(python3 "$PY_SCRIPT" "List employees in the Engineering department" "$DB_PATH" 2>&1)
# Should contain Alice Johnson, Bob Smith, Carol Williams but NOT David Brown etc.
ENG_COUNT=0
for name in "Alice Johnson" "Bob Smith" "Carol Williams"; do
    if echo "$OUTPUT2" | grep -qi "$name"; then
        ENG_COUNT=$((ENG_COUNT + 1))
    fi
done

NON_ENG=0
for name in "David Brown" "Eva Martinez" "Frank Lee" "Grace Kim" "Henry Chen" "Irene Davis" "Jack Wilson"; do
    if echo "$OUTPUT2" | grep -qi "$name"; then
        NON_ENG=$((NON_ENG + 1))
    fi
done

if [ "$ENG_COUNT" -eq 3 ] && [ "$NON_ENG" -eq 0 ]; then
    echo "${TEST_ID}|filter_department|PASS"
else
    echo "${TEST_ID}|filter_department|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
