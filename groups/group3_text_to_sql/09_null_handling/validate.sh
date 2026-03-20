#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="09_null_handling"

DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous DB
rm -f "$DB_PATH"

# Create SQLite DB from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "$TEST_ID|null_filter|FAIL"
    echo "$TEST_ID|not_null|FAIL"
    echo "$TEST_ID|count_nulls|FAIL"
    exit 1
fi

# Test 1: null_filter - "Which employees have no bonus?"
# Employees with NULL bonus: Carol Davis, Eva Lopez, Grace Hall, Irene Scott
OUTPUT1=$(python3 "$PY_SCRIPT" "Which employees have no bonus?" "$DB_PATH" 2>/dev/null)
PASS1=true
for name in "Carol Davis" "Eva Lopez" "Grace Hall" "Irene Scott"; do
    if ! echo "$OUTPUT1" | grep -qi "$name"; then
        PASS1=false
        break
    fi
done
# Should NOT contain employees who have a bonus
if echo "$OUTPUT1" | grep -qi "Alice Chen"; then
    PASS1=false
fi
if echo "$OUTPUT1" | grep -qi "Bob Park"; then
    PASS1=false
fi
if [ "$PASS1" = true ]; then
    echo "$TEST_ID|null_filter|PASS"
else
    echo "$TEST_ID|null_filter|FAIL"
fi

# Test 2: not_null - "List employees who have a manager"
# Employees with non-NULL manager_id: Bob Park, Carol Davis, Eva Lopez, Frank Kim, Henry Adams, Irene Scott, Jack Turner
OUTPUT2=$(python3 "$PY_SCRIPT" "List employees who have a manager" "$DB_PATH" 2>/dev/null)
PASS2=true
for name in "Bob Park" "Carol Davis" "Eva Lopez" "Frank Kim" "Henry Adams" "Irene Scott" "Jack Turner"; do
    if ! echo "$OUTPUT2" | grep -qi "$name"; then
        PASS2=false
        break
    fi
done
# Should NOT contain employees without a manager
if echo "$OUTPUT2" | grep -qi "Alice Chen"; then
    PASS2=false
fi
if echo "$OUTPUT2" | grep -qi "Dan Wilson"; then
    PASS2=false
fi
if echo "$OUTPUT2" | grep -qi "Grace Hall"; then
    PASS2=false
fi
if [ "$PASS2" = true ]; then
    echo "$TEST_ID|not_null|PASS"
else
    echo "$TEST_ID|not_null|FAIL"
fi

# Test 3: count_nulls - "How many employees don't have a bonus?"
# Answer: 4 (Carol Davis, Eva Lopez, Grace Hall, Irene Scott)
OUTPUT3=$(python3 "$PY_SCRIPT" "How many employees don't have a bonus?" "$DB_PATH" 2>/dev/null)
if echo "$OUTPUT3" | grep -q "4"; then
    echo "$TEST_ID|count_nulls|PASS"
else
    echo "$TEST_ID|count_nulls|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
