#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="08_webhook_receiver"
SAFE_PORT=18201

SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
    lsof -ti:$SAFE_PORT 2>/dev/null | xargs kill 2>/dev/null || true
}
trap cleanup EXIT

# Check 1: skill_and_server — SKILL.md with frontmatter + a .py server script
check1=FAIL
PY_SCRIPT=""
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---"; then
        PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
        [ -n "$PY_SCRIPT" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_server|${check1}"

# Patch port and start server
check2=FAIL
check3=FAIL
if [ -n "$PY_SCRIPT" ]; then
    for f in "$WORKSPACE"/*.py; do
        [ -f "$f" ] || continue
        sed -i '' \
            -e "s/port=5000/port=$SAFE_PORT/g" \
            -e "s/port=8000/port=$SAFE_PORT/g" \
            -e "s/port=8080/port=$SAFE_PORT/g" \
            -e "s/port=3000/port=$SAFE_PORT/g" \
            -e "s/port = 5000/port = $SAFE_PORT/g" \
            -e "s/port = 8000/port = $SAFE_PORT/g" \
            -e "s/port = 8080/port = $SAFE_PORT/g" \
            -e "s/PORT = 5000/PORT = $SAFE_PORT/g" \
            -e "s/PORT = 8000/PORT = $SAFE_PORT/g" \
            -e "s/PORT = 8080/PORT = $SAFE_PORT/g" \
            "$f" 2>/dev/null || true
    done
    export PORT=$SAFE_PORT

    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" &>/dev/null) &
    SERVER_PID=$!
    sleep 3

    # Check 2: server_starts
    if kill -0 $SERVER_PID 2>/dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SAFE_PORT" 2>/dev/null || echo "000")
        if echo "$HTTP_CODE" | grep -qE "^[2345]"; then
            check2=PASS
        fi
    fi

    # Check 3: logs_payload — POST a payload, check log file
    if [ "$check2" = "PASS" ]; then
        curl -s -X POST "http://localhost:$SAFE_PORT" \
            -H "Content-Type: application/json" \
            -d '{"event": "test", "data": "hello"}' >/dev/null 2>&1 || \
        curl -s -X POST "http://localhost:$SAFE_PORT/webhook" \
            -H "Content-Type: application/json" \
            -d '{"event": "test", "data": "hello"}' >/dev/null 2>&1 || true

        sleep 1
        # Find any log/jsonl file
        LOG_FILE=$(find "$WORKSPACE" -maxdepth 2 \( -name "*.jsonl" -o -name "*.log" -o -name "*log*.json" -o -name "*webhook*" \) -type f -newer "$PY_SCRIPT" 2>/dev/null | head -1)
        if [ -n "$LOG_FILE" ] && grep -q "test" "$LOG_FILE" 2>/dev/null && grep -q "hello" "$LOG_FILE" 2>/dev/null; then
            check3=PASS
        fi
    fi
fi
echo "${TEST_ID}|server_starts|${check2}"
echo "${TEST_ID}|logs_payload|${check3}"
