#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="09_task_board"

# Use a safe port that won't conflict with macOS AirPlay Receiver (port 5000)
SAFE_PORT=18113

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
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SAFE_PORT" 2>/dev/null | grep -qE "^[2345]"; then
        echo $SAFE_PORT; return 0
    fi
    for port in 8000 8080 3000 8888 5000; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "^[23]"; then
            echo $port; return 0
        fi
    done
    return 1
}

# Try to get page content — either via Python server or static HTML file
PAGE_CONTENT=""

# First try: find and start a Python server
PY_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
if [ -n "$PY_FILE" ]; then
    # Patch common port assignments to avoid conflicts (e.g. macOS AirPlay on 5000)
    for f in "$WORKSPACE"/*.py; do
        [ -f "$f" ] || continue
        sed -i '' \
            -e "s/port=5000/port=$SAFE_PORT/g" \
            -e "s/port=8000/port=$SAFE_PORT/g" \
            -e "s/port=3000/port=$SAFE_PORT/g" \
            -e "s/port=8080/port=$SAFE_PORT/g" \
            -e "s/port=8888/port=$SAFE_PORT/g" \
        -e "s/port=5001/port=$SAFE_PORT/g" \
        -e "s/port=5500/port=$SAFE_PORT/g" \
        -e "s/port = 5001/port = $SAFE_PORT/g" \
        -e "s/port = 5500/port = $SAFE_PORT/g" \
            -e "s/port = 5000/port = $SAFE_PORT/g" \
            -e "s/port = 8000/port = $SAFE_PORT/g" \
            -e "s/port = 3000/port = $SAFE_PORT/g" \
            -e "s/port = 8080/port = $SAFE_PORT/g" \
            -e "s/port = 8888/port = $SAFE_PORT/g" \
            "$f" 2>/dev/null || true
    done
    export PORT=$SAFE_PORT
    export FLASK_RUN_PORT=$SAFE_PORT

    cd "$WORKSPACE"
    python3 "$PY_FILE" > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 3

    PORT=$(detect_port || echo "")
    if [ -n "$PORT" ]; then
        PAGE_CONTENT=$(curl -s "http://localhost:$PORT" 2>/dev/null || echo "")
    fi
fi

# Fallback: read static HTML files directly (many models produce HTML-only solutions)
if [ -z "$PAGE_CONTENT" ]; then
    HTML_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "index.html" -type f | head -1)
    if [ -z "$HTML_FILE" ]; then
        HTML_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.html" -type f | head -1)
    fi
    if [ -n "$HTML_FILE" ]; then
        PAGE_CONTENT=$(cat "$HTML_FILE" 2>/dev/null || echo "")
    fi
fi

if [ -z "$PAGE_CONTENT" ]; then
    report "server_columns" "FAIL"
    report "add_cards" "FAIL"
    report "persistence" "FAIL"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 0
fi

# Check 1: page contains references to todo/doing/done
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
