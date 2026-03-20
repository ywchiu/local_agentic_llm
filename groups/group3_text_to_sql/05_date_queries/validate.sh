#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="05_date_queries"
DB_PATH="$WORKSPACE/test_db.sqlite"

# Clean up any previous database
rm -f "$DB_PATH"

# Create the SQLite database from fixture
sqlite3 "$DB_PATH" < "$FIXTURES/seed.sql"

# Find the Python script in workspace
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "${TEST_ID}|date_filter|FAIL"
    echo "${TEST_ID}|date_range|FAIL"
    echo "${TEST_ID}|recent_events|FAIL"
    exit 0
fi

# Check 1: date_filter - "Show events in January 2026"
# Events in Jan 2026: New Year Bash (2026-01-01), Winter Workshop (2026-01-18)
OUTPUT1=$(python3 "$PY_SCRIPT" "Show events in January 2026" "$DB_PATH" 2>&1)
JAN_CHECKS=0
if echo "$OUTPUT1" | grep -qi "New Year Bash"; then
    JAN_CHECKS=$((JAN_CHECKS + 1))
fi
if echo "$OUTPUT1" | grep -qi "Winter Workshop"; then
    JAN_CHECKS=$((JAN_CHECKS + 1))
fi

# Should NOT include events from other months
NON_JAN=0
for evt in "Spring Gala" "Tech Conference" "Summer Concert" "Music Awards" "Science Fair"; do
    if echo "$OUTPUT1" | grep -qi "$evt"; then
        NON_JAN=$((NON_JAN + 1))
    fi
done

if [ "$JAN_CHECKS" -eq 2 ] && [ "$NON_JAN" -eq 0 ]; then
    echo "${TEST_ID}|date_filter|PASS"
else
    echo "${TEST_ID}|date_filter|FAIL"
fi

# Check 2: date_range - "List events between 2025-06-01 and 2025-12-31"
# Events: Summer Concert (07-04), Art Exhibition (08-22), Charity Run (09-10),
#          Film Festival (10-30), Holiday Market (12-15) = 5 events
OUTPUT2=$(python3 "$PY_SCRIPT" "List events between 2025-06-01 and 2025-12-31" "$DB_PATH" 2>&1)
RANGE_CHECKS=0
for evt in "Summer Concert" "Art Exhibition" "Charity Run" "Film Festival" "Holiday Market"; do
    if echo "$OUTPUT2" | grep -qi "$evt"; then
        RANGE_CHECKS=$((RANGE_CHECKS + 1))
    fi
done

# Should NOT include events outside range
OUT_RANGE=0
for evt in "Spring Gala" "Tech Conference" "New Year Bash" "Science Fair"; do
    if echo "$OUTPUT2" | grep -qi "$evt"; then
        OUT_RANGE=$((OUT_RANGE + 1))
    fi
done

if [ "$RANGE_CHECKS" -ge 4 ] && [ "$OUT_RANGE" -eq 0 ]; then
    echo "${TEST_ID}|date_range|PASS"
else
    echo "${TEST_ID}|date_range|FAIL"
fi

# Check 3: recent_events - "What was the most recent event?"
# Most recent: Music Awards (2026-04-20)
OUTPUT3=$(python3 "$PY_SCRIPT" "What was the most recent event?" "$DB_PATH" 2>&1)
if echo "$OUTPUT3" | grep -qi "Music Awards"; then
    echo "${TEST_ID}|recent_events|PASS"
else
    echo "${TEST_ID}|recent_events|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
