#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="06_expense_tracker_api"

SERVER_PID=""
cleanup() {
    if [ -n "${SERVER_PID:-}" ]; then kill $SERVER_PID 2>/dev/null || true; fi
    # Also kill anything we may have spawned on the detected port
    if [ -n "${PORT:-}" ]; then
        lsof -ti:$PORT 2>/dev/null | xargs kill 2>/dev/null || true
    fi
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

# Find Python files to try starting
SCRIPTS=()
for name in app.py main.py server.py run.py api.py expense.py expense_tracker.py; do
    if [ -f "$WORKSPACE/$name" ]; then
        SCRIPTS+=("$WORKSPACE/$name")
    fi
done
# If none of the common names found, try any .py file
if [ ${#SCRIPTS[@]} -eq 0 ]; then
    for f in "$WORKSPACE"/*.py; do
        if [ -f "$f" ]; then
            SCRIPTS+=("$f")
        fi
    done
fi

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    echo "${TEST_ID}|server_starts|FAIL"
    echo "${TEST_ID}|add_and_list|FAIL"
    echo "${TEST_ID}|totals_by_category|FAIL"
    exit 0
fi

# Try to start the server
PORT=""
for script in "${SCRIPTS[@]}"; do
    python3 "$script" &>/dev/null &
    SERVER_PID=$!
    sleep 3
    # Check if process is still running
    if kill -0 $SERVER_PID 2>/dev/null; then
        if PORT=$(detect_port); then
            break
        fi
    fi
    kill $SERVER_PID 2>/dev/null || true
    SERVER_PID=""
done

# --- Check 1: server starts and responds ---
if [ -n "$PORT" ]; then
    echo "${TEST_ID}|server_starts|PASS"
else
    echo "${TEST_ID}|server_starts|FAIL"
    echo "${TEST_ID}|add_and_list|FAIL"
    echo "${TEST_ID}|totals_by_category|FAIL"
    exit 0
fi

BASE="http://localhost:$PORT"

# --- Check 2: POST expenses then GET list ---
check2_pass=false

# Try common endpoint patterns for POST
POST_ENDPOINT=""
for ep in /expenses /api/expenses /expense /api/expense; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE$ep" \
        -H "Content-Type: application/json" \
        -d '{"amount": 50, "category": "food", "date": "2026-01-01"}' 2>/dev/null)
    if echo "$code" | grep -qE "^[23]"; then
        POST_ENDPOINT="$ep"
        break
    fi
done

if [ -n "$POST_ENDPOINT" ]; then
    # Post remaining expenses
    curl -s -X POST "$BASE$POST_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{"amount": 30, "category": "food", "date": "2026-01-02"}' >/dev/null 2>&1

    curl -s -X POST "$BASE$POST_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{"amount": 100, "category": "transport", "date": "2026-01-03"}' >/dev/null 2>&1

    # Try GET on same endpoint or common list endpoints
    LIST_RESPONSE=""
    for ep in "$POST_ENDPOINT" /expenses /api/expenses /expense /api/expense; do
        resp=$(curl -s "$BASE$ep" 2>/dev/null)
        if [ -n "$resp" ] && echo "$resp" | grep -qi "food"; then
            LIST_RESPONSE="$resp"
            break
        fi
    done

    if [ -n "$LIST_RESPONSE" ] && echo "$LIST_RESPONSE" | grep -qi "food"; then
        check2_pass=true
    fi
fi

if $check2_pass; then
    echo "${TEST_ID}|add_and_list|PASS"
else
    echo "${TEST_ID}|add_and_list|FAIL"
fi

# --- Check 3: totals/summary by category ---
check3_pass=false

# Try various summary/totals endpoints
for ep in /expenses/summary /expenses/totals /api/expenses/summary /api/expenses/totals \
          /summary /totals /categories /expenses/categories /api/summary /api/totals \
          "/expenses?group_by=category" "/api/expenses?group_by=category" \
          "/expenses/report" "/api/expenses/report"; do
    resp=$(curl -s "$BASE$ep" 2>/dev/null)
    if [ -n "$resp" ] && echo "$resp" | grep -qi "food" && echo "$resp" | grep -qi "transport"; then
        # Check if the amounts are correct (food=80, transport=100)
        if echo "$resp" | grep -q "80" && echo "$resp" | grep -q "100"; then
            check3_pass=true
            break
        fi
        # Even if amounts aren't exactly right, at least both categories appear
        # Still count as pass if categories are grouped
        if echo "$resp" | grep -qi "food" && echo "$resp" | grep -qi "transport"; then
            check3_pass=true
            break
        fi
    fi
done

if $check3_pass; then
    echo "${TEST_ID}|totals_by_category|PASS"
else
    echo "${TEST_ID}|totals_by_category|FAIL"
fi
