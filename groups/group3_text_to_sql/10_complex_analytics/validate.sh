#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="10_complex_analytics"

DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous DB
rm -f "$DB_PATH"

# Create SQLite DB from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "$TEST_ID|account_summary|FAIL"
    echo "$TEST_ID|top_accounts|FAIL"
    echo "$TEST_ID|date_analysis|FAIL"
    exit 1
fi

# Test 1: account_summary - "Show total deposits and withdrawals per account"
# Account 1: deposits=4500, withdrawals=800
# Account 2: deposits=10000, withdrawals=1500
# Account 3: deposits=3500, withdrawals=900
# Account 4: deposits=8000, withdrawals=2300
# Account 5: deposits=1850, withdrawals=500
OUTPUT1=$(python3 "$PY_SCRIPT" "Show total deposits and withdrawals per account" "$DB_PATH" 2>/dev/null)
PASS1=true
# Check for key values - at least some deposit/withdrawal totals should appear
if ! echo "$OUTPUT1" | grep -q "4500"; then
    PASS1=false
fi
if ! echo "$OUTPUT1" | grep -q "10000"; then
    PASS1=false
fi
if ! echo "$OUTPUT1" | grep -q "8000"; then
    PASS1=false
fi
if [ "$PASS1" = true ]; then
    echo "$TEST_ID|account_summary|PASS"
else
    echo "$TEST_ID|account_summary|FAIL"
fi

# Test 2: top_accounts - "Which account has the highest total deposits?"
# Account 2 (Bob Taylor) has highest deposits: 10000
OUTPUT2=$(python3 "$PY_SCRIPT" "Which account has the highest total deposits?" "$DB_PATH" 2>/dev/null)
if echo "$OUTPUT2" | grep -qi "Bob Taylor\|account.*2\|10000"; then
    echo "$TEST_ID|top_accounts|PASS"
else
    echo "$TEST_ID|top_accounts|FAIL"
fi

# Test 3: date_analysis - "What is the total transaction amount per month?"
# January 2024: 2000+500+1500+5000+3000+1500+700+3000+500+200 = 17900
# February 2024: 1500+300+1000+800+1500+4000+750 = 9850
# March 2024: 1000+2000+500+200+1200+800+1000+300+600 = 7600
OUTPUT3=$(python3 "$PY_SCRIPT" "What is the total transaction amount per month?" "$DB_PATH" 2>/dev/null)
PASS3=true
# Check for monthly totals or at least that months appear with amounts
# Be flexible - look for the key total values
if ! echo "$OUTPUT3" | grep -q "17900\|17,900"; then
    # Maybe they show month names or partial data - check for at least some monthly grouping
    if ! echo "$OUTPUT3" | grep -qi "2024-01\|january\|Jan"; then
        PASS3=false
    fi
fi
if ! echo "$OUTPUT3" | grep -q "9850\|9,850"; then
    if ! echo "$OUTPUT3" | grep -qi "2024-02\|february\|Feb"; then
        PASS3=false
    fi
fi
if ! echo "$OUTPUT3" | grep -q "7600\|7,600"; then
    if ! echo "$OUTPUT3" | grep -qi "2024-03\|march\|Mar"; then
        PASS3=false
    fi
fi
if [ "$PASS3" = true ]; then
    echo "$TEST_ID|date_analysis|PASS"
else
    echo "$TEST_ID|date_analysis|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
