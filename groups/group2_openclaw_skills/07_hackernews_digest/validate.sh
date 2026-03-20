#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="07_hackernews_digest"

# Find SKILL.md — check workspace root first, then search subdirectories
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SKILL_DIR="$WORKSPACE"
else
    SKILL_DIR=$(find "$WORKSPACE" -name "SKILL.md" -type f -maxdepth 3 -print -quit 2>/dev/null | xargs dirname 2>/dev/null || echo "$WORKSPACE")
fi

MOCK_PID=""
cleanup() { [ -n "$MOCK_PID" ] && kill $MOCK_PID 2>/dev/null || true; }
trap cleanup EXIT

# Check 1: skill_and_script — SKILL.md with frontmatter + .py script exists
check1=FAIL
PY_SCRIPT=""
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    content=$(cat "$SKILL_DIR/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---"; then
        PY_SCRIPT=$(find "$SKILL_DIR" -maxdepth 2 -name "*.py" -type f | head -1)
        [ -n "$PY_SCRIPT" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Start mock HN API
python3 "$SCRIPT_DIR/fixtures/mock_hn_api.py" &
MOCK_PID=$!
sleep 1

# Check 2: produces_html — patch HN URL to localhost, run script, check .html output
check2=FAIL
if [ -n "$PY_SCRIPT" ]; then
    # Patch any HN API URLs to point at mock
    for f in "$SKILL_DIR"/*.py "$WORKSPACE"/*.py; do
        [ -f "$f" ] || continue
        sed -i '' \
            -e 's|https://hacker-news.firebaseio.com|http://127.0.0.1:18200|g' \
            -e 's|hacker-news.firebaseio.com|127.0.0.1:18200|g' \
            "$f" 2>/dev/null || true
    done

    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" 2>/dev/null) || true

    HTML_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.html" -type f | head -1)
    [ -n "$HTML_FILE" ] && check2=PASS
fi
echo "${TEST_ID}|produces_html|${check2}"

# Check 3: html_has_stories — HTML contains story titles and links
check3=FAIL
if [ -n "${HTML_FILE:-}" ] && [ -f "$HTML_FILE" ]; then
    html_content=$(cat "$HTML_FILE")
    stories_found=0
    for i in 1 2 3 4 5; do
        echo "$html_content" | grep -qi "Story $i" && stories_found=$((stories_found + 1))
    done
    [ "$stories_found" -ge 3 ] && check3=PASS
fi
echo "${TEST_ID}|html_has_stories|${check3}"
