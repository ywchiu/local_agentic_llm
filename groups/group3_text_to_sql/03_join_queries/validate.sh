#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="03_join_queries"
DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous database
rm -f "$DB_PATH"

# Create the SQLite database from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script in workspace
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "${TEST_ID}|simple_join|FAIL"
    echo "${TEST_ID}|multi_join|FAIL"
    echo "${TEST_ID}|join_with_agg|FAIL"
    exit 0
fi

# Check 1: simple_join - "Which students are enrolled in Math?" returns correct names
# Students in Math (course_id=1): Amy Turner, Brian Hall, Derek Fox, Finn Brooks, Hugo Rivera
OUTPUT1=$(python3 "$PY_SCRIPT" "Which students are enrolled in Math?" "$DB_PATH" 2>&1)
MATH_COUNT=0
for name in "Amy Turner" "Brian Hall" "Derek Fox" "Finn Brooks" "Hugo Rivera"; do
    if echo "$OUTPUT1" | grep -qi "$name"; then
        MATH_COUNT=$((MATH_COUNT + 1))
    fi
done

# Should NOT include students not in Math
NON_MATH=0
for name in "Chloe Adams" "Elena Cruz" "Gina Patel"; do
    if echo "$OUTPUT1" | grep -qi "$name"; then
        NON_MATH=$((NON_MATH + 1))
    fi
done

if [ "$MATH_COUNT" -eq 5 ] && [ "$NON_MATH" -eq 0 ]; then
    echo "${TEST_ID}|simple_join|PASS"
else
    echo "${TEST_ID}|simple_join|FAIL"
fi

# Check 2: multi_join - "Show each student's name and their course names" returns joined data
OUTPUT2=$(python3 "$PY_SCRIPT" "Show each student's name and their course names" "$DB_PATH" 2>&1)
# Check that output contains some expected student-course pairs
PAIR_COUNT=0
# Amy Turner takes Math and Science
if echo "$OUTPUT2" | grep -qi "Amy Turner" && echo "$OUTPUT2" | grep -qi "Math"; then
    PAIR_COUNT=$((PAIR_COUNT + 1))
fi
# Chloe Adams takes Science and History
if echo "$OUTPUT2" | grep -qi "Chloe Adams" && echo "$OUTPUT2" | grep -qi "Science"; then
    PAIR_COUNT=$((PAIR_COUNT + 1))
fi
# Brian Hall takes Math and English
if echo "$OUTPUT2" | grep -qi "Brian Hall" && echo "$OUTPUT2" | grep -qi "English"; then
    PAIR_COUNT=$((PAIR_COUNT + 1))
fi

# Should have at least 15 data lines (one per enrollment) - count non-empty, non-header lines
LINE_COUNT=$(echo "$OUTPUT2" | grep -ci "[a-z]")

if [ "$PAIR_COUNT" -ge 2 ] && [ "$LINE_COUNT" -ge 10 ]; then
    echo "${TEST_ID}|multi_join|PASS"
else
    echo "${TEST_ID}|multi_join|FAIL"
fi

# Check 3: join_with_agg - "How many students are in each course?" returns correct counts
# Math: 5, Science: 4, English: 3, History: 3
OUTPUT3=$(python3 "$PY_SCRIPT" "How many students are in each course?" "$DB_PATH" 2>&1)
CHECKS=0
if echo "$OUTPUT3" | grep -qi "Math" && echo "$OUTPUT3" | grep -q "5"; then
    CHECKS=$((CHECKS + 1))
fi
if echo "$OUTPUT3" | grep -qi "Science" && echo "$OUTPUT3" | grep -q "4"; then
    CHECKS=$((CHECKS + 1))
fi
if echo "$OUTPUT3" | grep -qi "English" && echo "$OUTPUT3" | grep -q "3"; then
    CHECKS=$((CHECKS + 1))
fi
if echo "$OUTPUT3" | grep -qi "History" && echo "$OUTPUT3" | grep -q "3"; then
    CHECKS=$((CHECKS + 1))
fi

if [ "$CHECKS" -ge 3 ]; then
    echo "${TEST_ID}|join_with_agg|PASS"
else
    echo "${TEST_ID}|join_with_agg|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
