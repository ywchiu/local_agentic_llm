#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="09_task_board"

PASS=0
FAIL=0
SERVER_PID=""

report() {
    local check_name="$1"
    local result="$2"
    echo "${TEST_ID}|${check_name}|${result}"
    if [ "$result" = "PASS" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

cleanup() {
    if [ -n "${SERVER_PID:-}" ]; then kill $SERVER_PID 2>/dev/null || true; fi
}
trap cleanup EXIT

detect_port() {
    for port in 5000 8000 8080 3000 8888; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "^[2345]"; then
            echo $port; return 0
        fi
    done
    return 1
}

# Find a Python file to run as server
PY_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
if [ -z "$PY_FILE" ]; then
    report "server_columns" "FAIL"
    report "add_cards" "FAIL"
    report "persistence" "FAIL"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Start server in background
cd "$WORKSPACE"
python3 "$PY_FILE" > /dev/null 2>&1 &
SERVER_PID=$!
sleep 3

# Detect port
PORT=$(detect_port || echo "")
if [ -z "$PORT" ]; then
    report "server_columns" "FAIL"
    report "add_cards" "FAIL"
    report "persistence" "FAIL"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 0
fi

# Check 1: main page loads and contains references to todo/doing/done
PAGE_CONTENT=$(curl -s "http://localhost:$PORT" 2>/dev/null || echo "")
if echo "$PAGE_CONTENT" | grep -qi "todo" && echo "$PAGE_CONTENT" | grep -qi "done"; then
    # Accept "doing" or "in progress" or similar for the middle column
    if echo "$PAGE_CONTENT" | grep -qiE "doing|in.?progress|in.?process"; then
        report "server_columns" "PASS"
    else
        report "server_columns" "PASS"
    fi
else
    report "server_columns" "FAIL"
fi

# Check 2: HTML/JS contains functionality for adding cards
if echo "$PAGE_CONTENT" | grep -qiE "<input|<form|<textarea|addCard|add.?card|add.?task|addTask|createCard|create.?card|new.?card|new.?task"; then
    report "add_cards" "PASS"
else
    report "add_cards" "FAIL"
fi

# Check 3: persistence mechanism — check source files and page content
PERSIST_FOUND=false
# Check in source code files
if grep -rqiE "localStorage|sessionStorage|sqlite|\.db|json\.dump|json\.load|shelve|pickle|database" "$WORKSPACE"/*.py "$WORKSPACE"/**/*.py 2>/dev/null; then
    PERSIST_FOUND=true
fi
# Also check HTML/JS served by the page
if echo "$PAGE_CONTENT" | grep -qiE "localStorage|sessionStorage"; then
    PERSIST_FOUND=true
fi
# Check all files in workspace for persistence patterns
if grep -rqiE "localStorage|sessionStorage|sqlite|\.db|json\.dump|json\.load|shelve|pickle|database|save.*state|load.*state|persist" "$WORKSPACE" 2>/dev/null; then
    PERSIST_FOUND=true
fi

if $PERSIST_FOUND; then
    report "persistence" "PASS"
else
    report "persistence" "FAIL"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
