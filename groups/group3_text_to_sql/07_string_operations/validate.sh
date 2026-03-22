#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="07_string_operations"

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
    echo "$TEST_ID|like_search|FAIL"
    echo "$TEST_ID|city_filter|FAIL"
    echo "$TEST_ID|email_domain|FAIL"
    exit 1
fi

# Test 1: like_search - "Find contacts whose last name starts with S"
# Expected: Smith, Sanders, Stevens, Sullivan, Scott, Simmons
OUTPUT1=$(python3 "$PY_SCRIPT" "Find contacts whose last name starts with S" "$DB_PATH" 2>/dev/null)
PASS1=true
for name in "Smith" "Sanders" "Stevens" "Sullivan" "Scott" "Simmons"; do
    if ! echo "$OUTPUT1" | grep -qi "$name"; then
        PASS1=false
        break
    fi
done
# Make sure non-S names don't appear alone (Johnson, Brown, Lee, etc.)
# Just check we got at least the S names
if [ "$PASS1" = true ]; then
    echo "$TEST_ID|like_search|PASS"
else
    echo "$TEST_ID|like_search|FAIL"
fi

# Test 2: city_filter - "Show all contacts in New York"
# Expected: Alice Smith, Dan Stevens, Frank Sullivan, Leo Simmons (4 contacts)
OUTPUT2=$(python3 "$PY_SCRIPT" "Show all contacts in New York" "$DB_PATH" 2>/dev/null)
PASS2=true
for name in "Alice" "Dan" "Frank" "Leo"; do
    if ! echo "$OUTPUT2" | grep -qi "$name"; then
        PASS2=false
        break
    fi
done
# Ensure non-NY contacts are not in output
if echo "$OUTPUT2" | grep -qi "Bob"; then
    PASS2=false
fi
if [ "$PASS2" = true ]; then
    echo "$TEST_ID|city_filter|PASS"
else
    echo "$TEST_ID|city_filter|FAIL"
fi

# Test 3: email_domain - "List contacts with gmail addresses"
# Expected: Alice Smith, Carol Sanders, Eva Brown, Henry Martinez, James Scott, Leo Simmons
OUTPUT3=$(python3 "$PY_SCRIPT" "List contacts with gmail addresses" "$DB_PATH" 2>/dev/null)
PASS3=true
for name in "Alice" "Carol" "Eva" "Henry" "James" "Leo"; do
    if ! echo "$OUTPUT3" | grep -qi "$name"; then
        PASS3=false
        break
    fi
done
# Ensure non-gmail contacts are not in output
if echo "$OUTPUT3" | grep -qi "Bob"; then
    PASS3=false
fi
if [ "$PASS3" = true ]; then
    echo "$TEST_ID|email_domain|PASS"
else
    echo "$TEST_ID|email_domain|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
