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
    # Aggressively patch ALL common port numbers to SAFE_PORT
    for f in "$WORKSPACE"/*.py; do
        [ -f "$f" ] || continue
        sed -i '' \
            -e "s/5000/$SAFE_PORT/g" \
            -e "s/8000/$SAFE_PORT/g" \
            -e "s/8080/$SAFE_PORT/g" \
            -e "s/3000/$SAFE_PORT/g" \
            -e "s/8888/$SAFE_PORT/g" \
            -e "s/9000/$SAFE_PORT/g" \
            -e "s/5001/$SAFE_PORT/g" \
            "$f" 2>/dev/null || true
    done
    export PORT=$SAFE_PORT
    export WEBHOOK_PORT=$SAFE_PORT

    # Try starting with --port flag first, then plain
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" --port $SAFE_PORT &>/dev/null 2>&1 || python3 "$PY_SCRIPT" &>/dev/null 2>&1) &
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

        sleep 2
        # Find any log/jsonl file (broad search — don't filter by -newer since sed modifies scripts)
        LOG_FILE=""
        for pattern in "*.jsonl" "*.log" "*payload*" "*webhook*log*" "*log*.json" "*events*"; do
            LOG_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "$pattern" -type f 2>/dev/null | head -1)
            [ -n "$LOG_FILE" ] && break
        done
        # Also check any new .json files that aren't the original script artifacts
        if [ -z "$LOG_FILE" ]; then
            LOG_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.json" ! -name "package.json" ! -name "requirements.json" -type f 2>/dev/null | head -1)
        fi
        if [ -n "$LOG_FILE" ] && grep -q "test" "$LOG_FILE" 2>/dev/null && grep -q "hello" "$LOG_FILE" 2>/dev/null; then
            check3=PASS
        fi
    fi
fi
echo "${TEST_ID}|server_starts|${check2}"
echo "${TEST_ID}|logs_payload|${check3}"
