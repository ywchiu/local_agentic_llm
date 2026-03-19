#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="10_realtime_chat"

# Use a safe port that won't conflict with macOS AirPlay Receiver (port 5000)
SAFE_PORT=18114

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

# Find Python files
PY_FILES=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f)
if [ -z "$PY_FILES" ]; then
    report "websocket_imports" "FAIL"
    report "server_starts" "FAIL"
    report "websocket_connect" "FAIL"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Check 1: source code imports websocket-related modules
if grep -rqiE "import websockets|from websockets|import socketio|from flask_socketio|import tornado\.websocket|from tornado\.websocket|import aiohttp|from aiohttp|websocket" "$WORKSPACE" --include="*.py" 2>/dev/null; then
    report "websocket_imports" "PASS"
else
    report "websocket_imports" "FAIL"
fi

# Find main Python file (look for one that runs a server)
MAIN_PY=$(grep -rlE "run\(|serve\(|main|app\.run|uvicorn|\.start\(" "$WORKSPACE" --include="*.py" 2>/dev/null | head -1)
if [ -z "$MAIN_PY" ]; then
    MAIN_PY=$(echo "$PY_FILES" | head -1)
fi

# Patch common port assignments in generated code to avoid conflicts (e.g. macOS AirPlay on 5000)
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

# Start server in background
cd "$WORKSPACE"
python3 "$MAIN_PY" > /dev/null 2>&1 &
SERVER_PID=$!
sleep 3

# Detect port
PORT=$(detect_port || echo "")

# Check 2: server starts and responds
if [ -n "$PORT" ]; then
    PAGE=$(curl -s "http://localhost:$PORT" 2>/dev/null || echo "")
    if [ -n "$PAGE" ]; then
        report "server_starts" "PASS"
    else
        report "server_starts" "FAIL"
    fi
else
    report "server_starts" "FAIL"
    report "websocket_connect" "FAIL"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 0
fi

# Check 3: test websocket connectivity
WS_RESULT=$(python3 -c "
import asyncio, sys

async def test():
    # Try plain websockets first
    try:
        import websockets
        async with websockets.connect('ws://localhost:${PORT}', timeout=5) as ws:
            print('connected via websockets')
            return True
    except Exception as e:
        print(f'ws failed: {e}')

    # Try websockets on /ws path
    try:
        import websockets
        async with websockets.connect('ws://localhost:${PORT}/ws', timeout=5) as ws:
            print('connected via websockets /ws')
            return True
    except Exception as e:
        print(f'ws /ws failed: {e}')

    # Try websockets on /chat path
    try:
        import websockets
        async with websockets.connect('ws://localhost:${PORT}/chat', timeout=5) as ws:
            print('connected via websockets /chat')
            return True
    except Exception as e:
        print(f'ws /chat failed: {e}')

    # Try socket.io
    try:
        import socketio
        sio = socketio.Client()
        sio.connect('http://localhost:${PORT}', wait_timeout=5)
        print('socketio connected')
        sio.disconnect()
        return True
    except Exception as e2:
        print(f'socketio failed: {e2}')

    return False

result = asyncio.run(test())
sys.exit(0 if result else 1)
" 2>&1) && WS_EXIT=0 || WS_EXIT=$?

if [ $WS_EXIT -eq 0 ]; then
    report "websocket_connect" "PASS"
else
    report "websocket_connect" "FAIL"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
