#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="03_calculator_web"

# Cleanup function to kill background processes
cleanup() {
    if [ -n "${SERVER_PID:-}" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Use a safe port that won't conflict with macOS AirPlay Receiver (port 5000)
SAFE_PORT=18110

SERVER_PID=""
HTML_CONTENT=""
IS_WEB_SERVER=false

# Find relevant files
HTML_FILES=$(find "$WORKSPACE" -name "*.html" -type f 2>/dev/null || true)
PY_FILES=$(find "$WORKSPACE" -name "*.py" -type f 2>/dev/null || true)

if [ -z "$HTML_FILES" ] && [ -z "$PY_FILES" ]; then
    echo "$TEST_ID|app_loads|FAIL"
    echo "$TEST_ID|has_ui_elements|FAIL"
    echo "$TEST_ID|has_math_operations|FAIL"
    exit 0
fi

# Determine if this is a Python web app or pure HTML
if [ -n "$PY_FILES" ]; then
    # Check if any Python file looks like a web server
    for py_file in $PY_FILES; do
        if grep -qiE "flask|django|fastapi|http\.server|bottle|tornado|cherrypy|uvicorn|gunicorn" "$py_file" 2>/dev/null; then
            IS_WEB_SERVER=true
            break
        fi
    done
fi

# Check 1: App loads
if $IS_WEB_SERVER; then
    # Patch ANY port assignment in generated code to use the safe port
    for f in "$WORKSPACE"/*.py; do
        [ -f "$f" ] || continue
        sed -i '' \
            -E "s/port[[:space:]]*=[[:space:]]*[0-9]{2,5}/port=$SAFE_PORT/g" \
            "$f" 2>/dev/null || true
        sed -i '' \
            -e "s/app\.run(debug=True)/app.run(debug=True, port=$SAFE_PORT)/g" \
            -e "s/app\.run()/app.run(port=$SAFE_PORT)/g" \
            "$f" 2>/dev/null || true
    done
    export PORT=$SAFE_PORT
    export FLASK_RUN_PORT=$SAFE_PORT

    # Try to start the Python web app
    for entry in app.py main.py server.py; do
        CANDIDATE="$WORKSPACE/$entry"
        if [ -f "$CANDIDATE" ]; then
            cd "$WORKSPACE"
            python3 "$CANDIDATE" &>/dev/null &
            SERVER_PID=$!
            break
        fi
    done

    # If no standard name found, try the first Python file that imports a web framework
    if [ -z "$SERVER_PID" ]; then
        for py_file in $PY_FILES; do
            if grep -qiE "flask|fastapi|bottle|http\.server" "$py_file" 2>/dev/null; then
                cd "$WORKSPACE"
                python3 "$py_file" &>/dev/null &
                SERVER_PID=$!
                break
            fi
        done
    fi

    sleep 3

    # Try common ports (safe port first)
    SERVER_RESPONDED=false
    for port in $SAFE_PORT 8000 8080 3000 8888 5500 5000; do
        if HTML_CONTENT=$(curl -s --max-time 3 "http://localhost:$port" 2>/dev/null) && [ -n "$HTML_CONTENT" ]; then
            SERVER_RESPONDED=true
            break
        fi
    done

    if $SERVER_RESPONDED; then
        echo "$TEST_ID|app_loads|PASS"
    else
        echo "$TEST_ID|app_loads|FAIL"
        # Fall back to checking HTML files directly
        if [ -n "$HTML_FILES" ]; then
            HTML_CONTENT=$(cat $(echo "$HTML_FILES" | head -n 1) 2>/dev/null || true)
        fi
    fi
else
    # Pure HTML - check file exists and looks like valid HTML
    if [ -n "$HTML_FILES" ]; then
        MAIN_HTML=$(echo "$HTML_FILES" | head -n 1)
        HTML_CONTENT=$(cat "$MAIN_HTML" 2>/dev/null || true)
        if echo "$HTML_CONTENT" | grep -qiE "<html|<body|<div|<button|<!DOCTYPE" 2>/dev/null; then
            echo "$TEST_ID|app_loads|PASS"
        else
            echo "$TEST_ID|app_loads|FAIL"
        fi
    else
        echo "$TEST_ID|app_loads|FAIL"
    fi
fi

# Also gather content from all HTML and JS files for checks 2 and 3
ALL_CONTENT="$HTML_CONTENT"
for f in $(find "$WORKSPACE" -name "*.html" -o -name "*.js" -o -name "*.py" 2>/dev/null); do
    ALL_CONTENT="$ALL_CONTENT $(cat "$f" 2>/dev/null || true)"
done

# Check 2: Has UI elements (buttons or inputs for calculator)
if echo "$ALL_CONTENT" | grep -qiE "<button|<input|onclick|addEventListener|btn|keyboard" 2>/dev/null; then
    echo "$TEST_ID|has_ui_elements|PASS"
else
    echo "$TEST_ID|has_ui_elements|FAIL"
fi

# Check 3: Has math operations
if echo "$ALL_CONTENT" | grep -qiE "[\+\-\*\/]|add|subtract|multiply|divide|plus|minus|eval|calculate|operation" 2>/dev/null; then
    echo "$TEST_ID|has_math_operations|PASS"
else
    echo "$TEST_ID|has_math_operations|FAIL"
fi
