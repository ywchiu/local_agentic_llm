#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="06_subqueries"

DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous DB
rm -f "$DB_PATH"

# Create SQLite DB from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script
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
    echo "$TEST_ID|subquery_max|FAIL"
    echo "$TEST_ID|subquery_in|FAIL"
    echo "$TEST_ID|subquery_compare|FAIL"
    exit 1
fi

# Test 1: subquery_max - "What is the most expensive product?"
# Expected: Laptop Pro (price 1299.99)
OUTPUT1=$(python3 "$PY_SCRIPT" "What is the most expensive product?" "$DB_PATH" 2>/dev/null)
if echo "$OUTPUT1" | grep -qi "Laptop Pro"; then
    echo "$TEST_ID|subquery_max|PASS"
else
    echo "$TEST_ID|subquery_max|FAIL"
fi

# Test 2: subquery_in - "Which products are stocked in the NYC warehouse?"
# Expected: Laptop Pro, Wireless Mouse, USB-C Cable, Ergonomic Chair, Monitor 27in, Keyboard Mechanical, Webcam HD, Notebook Pack
OUTPUT2=$(python3 "$PY_SCRIPT" "Which products are stocked in the NYC warehouse?" "$DB_PATH" 2>/dev/null)
PASS2=true
for product in "Laptop Pro" "Wireless Mouse" "Ergonomic Chair" "Monitor 27in" "Keyboard Mechanical" "Webcam HD" "Notebook Pack"; do
    if ! echo "$OUTPUT2" | grep -qi "$product"; then
        PASS2=false
        break
    fi
done
# Also check that Standing Desk and Desk Lamp are NOT in the output (they are not in NYC)
if echo "$OUTPUT2" | grep -qi "Standing Desk"; then
    PASS2=false
fi
if [ "$PASS2" = true ]; then
    echo "$TEST_ID|subquery_in|PASS"
else
    echo "$TEST_ID|subquery_in|FAIL"
fi

# Test 3: subquery_compare - "Which products cost more than the average price?"
# Average price = (1299.99+29.99+12.99+549+399+449.99+89.99+45+79.99+15.99)/10 = 297.193
# Products above average: Laptop Pro (1299.99), Standing Desk (549), Ergonomic Chair (399), Monitor 27in (449.99)
OUTPUT3=$(python3 "$PY_SCRIPT" "Which products cost more than the average price?" "$DB_PATH" 2>/dev/null)
PASS3=true
for product in "Laptop Pro" "Standing Desk" "Ergonomic Chair" "Monitor 27in"; do
    if ! echo "$OUTPUT3" | grep -qi "$product"; then
        PASS3=false
        break
    fi
done
# Check that cheap products are NOT in output
if echo "$OUTPUT3" | grep -qi "Wireless Mouse"; then
    PASS3=false
fi
if [ "$PASS3" = true ]; then
    echo "$TEST_ID|subquery_compare|PASS"
else
    echo "$TEST_ID|subquery_compare|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
