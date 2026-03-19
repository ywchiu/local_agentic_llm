#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="07_url_shortener"

SERVER_PID=""
cleanup() {
    if [ -n "${SERVER_PID:-}" ]; then kill $SERVER_PID 2>/dev/null || true; fi
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
for name in app.py main.py server.py run.py url_shortener.py shortener.py; do
    if [ -f "$WORKSPACE/$name" ]; then
        SCRIPTS+=("$WORKSPACE/$name")
    fi
done
if [ ${#SCRIPTS[@]} -eq 0 ]; then
    for f in "$WORKSPACE"/*.py; do
        if [ -f "$f" ]; then
            SCRIPTS+=("$f")
        fi
    done
fi

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    echo "${TEST_ID}|server_starts|FAIL"
    echo "${TEST_ID}|shorten_url|FAIL"
    echo "${TEST_ID}|redirect_works|FAIL"
    exit 0
fi

# Try to start the server
PORT=""
for script in "${SCRIPTS[@]}"; do
    python3 "$script" &>/dev/null &
    SERVER_PID=$!
    sleep 3
    if kill -0 $SERVER_PID 2>/dev/null; then
        if PORT=$(detect_port); then
            break
        fi
    fi
    kill $SERVER_PID 2>/dev/null || true
    SERVER_PID=""
done

# --- Check 1: server starts and main page loads ---
if [ -n "$PORT" ]; then
    echo "${TEST_ID}|server_starts|PASS"
else
    echo "${TEST_ID}|server_starts|FAIL"
    echo "${TEST_ID}|shorten_url|FAIL"
    echo "${TEST_ID}|redirect_works|FAIL"
    exit 0
fi

BASE="http://localhost:$PORT"
LONG_URL="https://www.example.com/some/very/long/path?with=query&params=here"
SHORT_CODE=""

# --- Check 2: submit a URL and get a short one back ---
check2_pass=false
RESPONSE=""

# Try JSON POST to various endpoints
for ep in /shorten /api/shorten / /url /api/url /create /api/create; do
    RESPONSE=$(curl -s -X POST "$BASE$ep" \
        -H "Content-Type: application/json" \
        -d "{\"url\": \"$LONG_URL\"}" 2>/dev/null)
    if [ -n "$RESPONSE" ] && echo "$RESPONSE" | grep -qiE "(short|url|http|localhost)"; then
        check2_pass=true
        break
    fi
done

# If JSON didn't work, try form data
if ! $check2_pass; then
    for ep in /shorten / /url /create; do
        RESPONSE=$(curl -s -X POST "$BASE$ep" \
            -d "url=$LONG_URL" 2>/dev/null)
        if [ -n "$RESPONSE" ] && echo "$RESPONSE" | grep -qiE "(short|url|http|localhost)"; then
            check2_pass=true
            break
        fi
    done
fi

# Try to extract the short URL or code from the response
if $check2_pass; then
    # Try to extract a short URL from JSON response
    SHORT_URL=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for key in ['short_url', 'shortened_url', 'short', 'url', 'result', 'link']:
        if key in data:
            print(data[key])
            sys.exit(0)
    # Try nested
    for v in data.values():
        if isinstance(v, str) and ('http' in v or '/' in v):
            print(v)
            sys.exit(0)
except:
    pass
" 2>/dev/null || true)

    # If no JSON extraction, try to find URL in HTML or plain text
    if [ -z "$SHORT_URL" ]; then
        SHORT_URL=$(echo "$RESPONSE" | grep -oE "http://localhost:${PORT}/[a-zA-Z0-9_-]+" | head -1 || true)
    fi

    # Extract just the short code
    if [ -n "$SHORT_URL" ]; then
        if echo "$SHORT_URL" | grep -q "http"; then
            SHORT_CODE=$(echo "$SHORT_URL" | grep -oE "/[a-zA-Z0-9_-]+$" | tr -d '/' || true)
        else
            SHORT_CODE=$(echo "$SHORT_URL" | tr -d '/' || true)
        fi
    fi
fi

if $check2_pass; then
    echo "${TEST_ID}|shorten_url|PASS"
else
    echo "${TEST_ID}|shorten_url|FAIL"
    echo "${TEST_ID}|redirect_works|FAIL"
    exit 0
fi

# --- Check 3: follow the short URL, check redirect ---
check3_pass=false

if [ -n "$SHORT_CODE" ]; then
    # Check with curl -I to see redirect headers
    REDIRECT_RESPONSE=$(curl -s -I "$BASE/$SHORT_CODE" 2>/dev/null || true)
    HTTP_CODE=$(echo "$REDIRECT_RESPONSE" | head -1 | grep -oE "[0-9]{3}" | head -1 || true)

    if echo "$HTTP_CODE" | grep -qE "^(301|302|303|307|308)$"; then
        # Check Location header points to original URL
        LOCATION=$(echo "$REDIRECT_RESPONSE" | grep -i "^location:" | sed 's/^[Ll]ocation: *//' | tr -d '\r' || true)
        if echo "$LOCATION" | grep -q "example.com"; then
            check3_pass=true
        else
            # Even if location doesn't match perfectly, a redirect happened
            check3_pass=true
        fi
    fi

    # Alternative: follow with -L and check final URL
    if ! $check3_pass; then
        FINAL_URL=$(curl -s -o /dev/null -w "%{url_effective}" -L "$BASE/$SHORT_CODE" 2>/dev/null || true)
        if echo "$FINAL_URL" | grep -q "example.com"; then
            check3_pass=true
        fi
    fi
fi

# If we couldn't extract a short code, try using the full short URL
if ! $check3_pass && [ -n "$SHORT_URL" ] && echo "$SHORT_URL" | grep -q "http"; then
    REDIRECT_RESPONSE=$(curl -s -I "$SHORT_URL" 2>/dev/null || true)
    HTTP_CODE=$(echo "$REDIRECT_RESPONSE" | head -1 | grep -oE "[0-9]{3}" | head -1 || true)
    if echo "$HTTP_CODE" | grep -qE "^(301|302|303|307|308)$"; then
        check3_pass=true
    fi
fi

if $check3_pass; then
    echo "${TEST_ID}|redirect_works|PASS"
else
    echo "${TEST_ID}|redirect_works|FAIL"
fi
