#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="08_ordering_and_limits"

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
    echo "$TEST_ID|top_rated|FAIL"
    echo "$TEST_ID|longest_books|FAIL"
    echo "$TEST_ID|newest_books|FAIL"
    exit 1
fi

# Test 1: top_rated - "What are the top 3 highest rated books?"
# By rating desc: Project Hail Mary (4.8), Educated (4.7), Dune (4.6) / Demon Copperhead (4.6)
OUTPUT1=$(python3 "$PY_SCRIPT" "What are the top 3 highest rated books?" "$DB_PATH" 2>/dev/null)
PASS1=true
for title in "Project Hail Mary" "Educated"; do
    if ! echo "$OUTPUT1" | grep -qi "$title"; then
        PASS1=false
        break
    fi
done
# Third could be Dune or Demon Copperhead (both 4.6)
if ! echo "$OUTPUT1" | grep -qi "Dune\|Demon Copperhead"; then
    PASS1=false
fi
# Should NOT contain low-rated books
if echo "$OUTPUT1" | grep -qi "Sea of Tranquility"; then
    PASS1=false
fi
# Count output lines (excluding headers) - should be around 3
LINE_COUNT=$(echo "$OUTPUT1" | grep -ci "Project Hail Mary\|Educated\|Dune\|Demon Copperhead\|Song of Achilles\|To Kill")
if [ "$LINE_COUNT" -gt 4 ]; then
    PASS1=false
fi
if [ "$PASS1" = true ]; then
    echo "$TEST_ID|top_rated|PASS"
else
    echo "$TEST_ID|top_rated|FAIL"
fi

# Test 2: longest_books - "Show the 5 longest books by page count"
# By pages desc: Dune (688), Demon Copperhead (560), Project Hail Mary (496), Sapiens (464), Song of Achilles (416) / Tomorrow... (416)
OUTPUT2=$(python3 "$PY_SCRIPT" "Show the 5 longest books by page count" "$DB_PATH" 2>/dev/null)
PASS2=true
for title in "Dune" "Demon Copperhead" "Project Hail Mary" "Sapiens"; do
    if ! echo "$OUTPUT2" | grep -qi "$title"; then
        PASS2=false
        break
    fi
done
# Should NOT contain short books
if echo "$OUTPUT2" | grep -qi "Great Gatsby"; then
    PASS2=false
fi
if [ "$PASS2" = true ]; then
    echo "$TEST_ID|longest_books|PASS"
else
    echo "$TEST_ID|longest_books|FAIL"
fi

# Test 3: newest_books - "List books published after 2020 ordered by year"
# 2021: Project Hail Mary, Klara and the Sun
# 2022: Tomorrow..., Demon Copperhead, Lessons in Chemistry, Sea of Tranquility
OUTPUT3=$(python3 "$PY_SCRIPT" "List books published after 2020 ordered by year" "$DB_PATH" 2>/dev/null)
PASS3=true
for title in "Project Hail Mary" "Klara and the Sun" "Demon Copperhead" "Lessons in Chemistry" "Sea of Tranquility"; do
    if ! echo "$OUTPUT3" | grep -qi "$title"; then
        PASS3=false
        break
    fi
done
# Should NOT contain pre-2021 books
if echo "$OUTPUT3" | grep -qi "Dune"; then
    PASS3=false
fi
if echo "$OUTPUT3" | grep -qi "Great Gatsby"; then
    PASS3=false
fi
if [ "$PASS3" = true ]; then
    echo "$TEST_ID|newest_books|PASS"
else
    echo "$TEST_ID|newest_books|FAIL"
fi

# Clean up
rm -f "$DB_PATH"
