#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="01_csv_to_json"

# Find a Python script in workspace
PY_SCRIPT=$(find "$WORKSPACE" -name "*.py" -type f | head -n 1)

if [ -z "$PY_SCRIPT" ]; then
    echo "$TEST_ID|runs_on_simple_csv|FAIL"
    echo "$TEST_ID|valid_json_output|FAIL"
    echo "$TEST_ID|handles_missing_values|FAIL"
    exit 0
fi

# Check 1: Script runs without error on simple.csv
if python3 "$PY_SCRIPT" "$FIXTURES/simple.csv" > /tmp/csv_simple_out.json 2>/dev/null; then
    echo "$TEST_ID|runs_on_simple_csv|PASS"
else
    echo "$TEST_ID|runs_on_simple_csv|FAIL"
fi

# Check 2: Output is valid JSON (try simple.csv and semicolon.csv)
VALID_JSON=true
for csv_file in "$FIXTURES/simple.csv" "$FIXTURES/semicolon.csv"; do
    OUTPUT=$(python3 "$PY_SCRIPT" "$csv_file" 2>/dev/null || true)
    if [ -z "$OUTPUT" ]; then
        # Some scripts write to a file instead of stdout; look for json files
        JSON_FILE=$(find "$WORKSPACE" -name "*.json" -newer "$csv_file" -type f 2>/dev/null | head -n 1)
        if [ -n "$JSON_FILE" ]; then
            OUTPUT=$(cat "$JSON_FILE")
        fi
    fi
    if [ -n "$OUTPUT" ]; then
        if ! echo "$OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
            VALID_JSON=false
        fi
    else
        VALID_JSON=false
    fi
done

if $VALID_JSON; then
    echo "$TEST_ID|valid_json_output|PASS"
else
    echo "$TEST_ID|valid_json_output|FAIL"
fi

# Check 3: Handles missing values - output should be valid JSON with null or empty strings
OUTPUT=$(python3 "$PY_SCRIPT" "$FIXTURES/missing.csv" 2>/dev/null || true)
if [ -z "$OUTPUT" ]; then
    JSON_FILE=$(find "$WORKSPACE" -name "*.json" -type f -newer "$FIXTURES/missing.csv" 2>/dev/null | head -n 1)
    if [ -n "$JSON_FILE" ]; then
        OUTPUT=$(cat "$JSON_FILE")
    fi
fi

if [ -n "$OUTPUT" ] && echo "$OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    # Check that the JSON contains null or empty string values for missing fields
    if echo "$OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list):
    records = data
elif isinstance(data, dict):
    # Try common wrapper keys
    for key in data:
        if isinstance(data[key], list):
            records = data[key]
            break
    else:
        records = [data]
else:
    records = []
found_empty = False
for rec in records:
    for v in rec.values():
        if v is None or v == '' or v == 'null':
            found_empty = True
            break
    if found_empty:
        break
sys.exit(0 if found_empty else 1)
" 2>/dev/null; then
        echo "$TEST_ID|handles_missing_values|PASS"
    else
        echo "$TEST_ID|handles_missing_values|FAIL"
    fi
else
    echo "$TEST_ID|handles_missing_values|FAIL"
fi
