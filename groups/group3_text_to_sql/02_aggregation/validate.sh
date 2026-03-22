#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="02_aggregation"
DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous database
rm -f "$DB_PATH"

# Create the SQLite database from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script in workspace
# Prefer text_to_sql.py, then *sql*/*query* scripts, then any .py (excluding test/setup helpers)
if [ -f "$WORKSPACE/text_to_sql.py" ]; then
    PY_SCRIPT="$WORKSPACE/text_to_sql.py"
else
    PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 \( -name "*sql*.py" -o -name "*query*.py" -o -name "*translate*.py" \) -type f | head -n 1)
    if [ -z "$PY_SCRIPT" ]; then
        PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 1 -name "*.py" -type f ! -name "test_*" ! -name "*_test.py" ! -name "create_*" ! -name "setup_*" ! -name "example*" | head -n 1)
    fi
    if [ -z "$PY_SCRIPT" ]; then
        PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)
    fi
fi

if [ -z "$PY_SCRIPT" ]; then
    echo "${TEST_ID}|count_query|FAIL"
    echo "${TEST_ID}|sum_query|FAIL"
    echo "${TEST_ID}|avg_query|FAIL"
    exit 0
fi

# Check 1: count_query - "How many orders are there?" returns 15
OUTPUT1=$(python3 "$PY_SCRIPT" "How many orders are there?" "$DB_PATH" 2>&1)
if echo "$OUTPUT1" | grep -q "15"; then
    echo "${TEST_ID}|count_query|PASS"
else
    echo "${TEST_ID}|count_query|FAIL"
fi

# Check 2: sum_query - "What is the total revenue?" returns 2675
# Total revenue = SUM(quantity * price) = 2675.0
OUTPUT2=$(python3 "$PY_SCRIPT" "What is the total revenue?" "$DB_PATH" 2>&1)
if echo "$OUTPUT2" | grep -q "2675"; then
    echo "${TEST_ID}|sum_query|PASS"
else
    echo "${TEST_ID}|sum_query|FAIL"
fi

# Check 3: avg_query - "What is the average order price?" returns 70
# Average price = 1050 / 15 = 70.0
OUTPUT3=$(python3 "$PY_SCRIPT" "What is the average order price?" "$DB_PATH" 2>&1)
if echo "$OUTPUT3" | grep -q "70"; then
    echo "${TEST_ID}|avg_query|PASS"
else
    echo "${TEST_ID}|avg_query|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
