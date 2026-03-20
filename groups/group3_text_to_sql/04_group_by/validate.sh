#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="04_group_by"
DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous database
rm -f "$DB_PATH"

# Create the SQLite database from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script in workspace
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "${TEST_ID}|group_by_region|FAIL"
    echo "${TEST_ID}|having_clause|FAIL"
    echo "${TEST_ID}|group_count|FAIL"
    exit 0
fi

# Check 1: group_by_region - "What are the total sales by region?"
# North: 250+320+150+220+415+310+290 = 1955
# South: 430+510+480+340+360+440 = 2560
# East: 180+290+370+195+275+185+525 = 2020
OUTPUT1=$(python3 "$PY_SCRIPT" "What are the total sales by region?" "$DB_PATH" 2>&1)
REGION_CHECKS=0
if echo "$OUTPUT1" | grep -qi "North" && echo "$OUTPUT1" | grep -q "1955"; then
    REGION_CHECKS=$((REGION_CHECKS + 1))
fi
if echo "$OUTPUT1" | grep -qi "South" && echo "$OUTPUT1" | grep -q "2560"; then
    REGION_CHECKS=$((REGION_CHECKS + 1))
fi
if echo "$OUTPUT1" | grep -qi "East" && echo "$OUTPUT1" | grep -q "2020"; then
    REGION_CHECKS=$((REGION_CHECKS + 1))
fi

if [ "$REGION_CHECKS" -ge 3 ]; then
    echo "${TEST_ID}|group_by_region|PASS"
else
    echo "${TEST_ID}|group_by_region|FAIL"
fi

# Check 2: having_clause - "Which salespeople have total sales over 1000?"
# Alice: 250+320+480+195+310 = 1555
# Bob: 430+290+220+360+185 = 1485
# Carol: 180+150+340+275+290 = 1235
# David: 510+370+415+440+525 = 2260
# All four have total sales over 1000
OUTPUT2=$(python3 "$PY_SCRIPT" "Which salespeople have total sales over 1000?" "$DB_PATH" 2>&1)
HAVING_CHECKS=0
for name in "Alice" "Bob" "Carol" "David"; do
    if echo "$OUTPUT2" | grep -qi "$name"; then
        HAVING_CHECKS=$((HAVING_CHECKS + 1))
    fi
done

if [ "$HAVING_CHECKS" -eq 4 ]; then
    echo "${TEST_ID}|having_clause|PASS"
else
    echo "${TEST_ID}|having_clause|FAIL"
fi

# Check 3: group_count - "How many sales did each salesperson make?"
# Alice: 5, Bob: 5, Carol: 5, David: 5
OUTPUT3=$(python3 "$PY_SCRIPT" "How many sales did each salesperson make?" "$DB_PATH" 2>&1)
COUNT_CHECKS=0
# Each salesperson should appear with count 5
for name in "Alice" "Bob" "Carol" "David"; do
    if echo "$OUTPUT3" | grep -qi "$name"; then
        COUNT_CHECKS=$((COUNT_CHECKS + 1))
    fi
done

# Check that 5 appears in the output (all have 5 sales)
if [ "$COUNT_CHECKS" -eq 4 ] && echo "$OUTPUT3" | grep -q "5"; then
    echo "${TEST_ID}|group_count|PASS"
else
    echo "${TEST_ID}|group_count|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
