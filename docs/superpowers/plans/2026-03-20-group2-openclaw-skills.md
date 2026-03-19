# Group 2: OpenClaw Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 10 benchmark tests for OpenClaw skill building, with prompts, fixtures, and validation scripts.

**Architecture:** Each test is a directory with prompt.md, validate.sh, optional setup.sh, optional fixtures/, and an empty workspace/. Follows the exact same patterns as Group 1. Validation scripts output `TEST_ID|check_name|PASS` or `FAIL`.

**Tech Stack:** Bash, Python 3 stdlib, grep, curl

**Spec:** `docs/superpowers/specs/2026-03-20-group2-openclaw-skills-design.md`

---

## File Structure

```
groups/group2_openclaw_skills/
├── 01_pomodoro_timer/        prompt.md, validate.sh, workspace/.gitkeep
├── 02_fix_broken_skill/      prompt.md, validate.sh, setup.sh, fixtures/{SKILL.md, run.sh}, workspace/.gitkeep
├── 03_bookmark_manager/      prompt.md, validate.sh, workspace/.gitkeep
├── 04_weather_lookup/        prompt.md, validate.sh, workspace/.gitkeep
├── 05_github_pr_summary/     prompt.md, validate.sh, workspace/.gitkeep
├── 06_file_organizer/        prompt.md, validate.sh, setup.sh, fixtures/messy_dir/{5 files}, workspace/.gitkeep
├── 07_hackernews_digest/     prompt.md, validate.sh, fixtures/mock_hn_api.py, workspace/.gitkeep
├── 08_webhook_receiver/      prompt.md, validate.sh, workspace/.gitkeep
├── 09_data_pipeline/         prompt.md, validate.sh, setup.sh, fixtures/posts.json, workspace/.gitkeep
├── 10_smart_home_controller/ prompt.md, validate.sh, setup.sh, fixtures/devices.json, workspace/.gitkeep
```

---

### Task 1: Create Easy Tier — Tests 01, 02, 03

**Files:**
- Create: `groups/group2_openclaw_skills/01_pomodoro_timer/{prompt.md, validate.sh, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/02_fix_broken_skill/{prompt.md, validate.sh, setup.sh, fixtures/SKILL.md, fixtures/run.sh, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/03_bookmark_manager/{prompt.md, validate.sh, workspace/.gitkeep}`

- [ ] **Step 1: Create directory structure for tests 01-03**

```bash
for t in 01_pomodoro_timer 02_fix_broken_skill 03_bookmark_manager; do
    mkdir -p groups/group2_openclaw_skills/$t/{fixtures,workspace}
    touch groups/group2_openclaw_skills/$t/workspace/.gitkeep
done
mkdir -p groups/group2_openclaw_skills/02_fix_broken_skill/fixtures
```

- [ ] **Step 2: Create test 01 — Pomodoro Timer**

`groups/group2_openclaw_skills/01_pomodoro_timer/prompt.md`:
```
Build an OpenClaw skill that tracks pomodoro work sessions. It should let you start a timer, check remaining time, and log completed sessions to a file. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/01_pomodoro_timer/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="01_pomodoro_timer"

# Check 1: skill_structure — SKILL.md with valid frontmatter (name + description)
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        # Check closing --- and body after it
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        if [ -n "$close_line" ]; then
            body=$(echo "$content" | tail -n +"$((close_line + 1))" | tr -d '[:space:]')
            [ -n "$body" ] && check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: has_timer_logic — mentions timer/pomodoro concepts
check2=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "timer|pomodoro|countdown|minutes|duration|25.*min|start.*session|stop.*session"; then
    check2=PASS
fi
echo "${TEST_ID}|has_timer_logic|${check2}"

# Check 3: session_logging — writes sessions to a log/file
check3=FAIL
if echo "$ALL_CONTENT" | grep -qiE "log|\.txt|\.csv|\.json|write.*file|append|completed.*session|session.*record"; then
    check3=PASS
fi
echo "${TEST_ID}|session_logging|${check3}"
```

- [ ] **Step 3: Create test 02 — Fix Broken Skill**

`groups/group2_openclaw_skills/02_fix_broken_skill/prompt.md`:
```
There's a broken OpenClaw skill in this directory. The SKILL.md has formatting issues and the companion script has a bug. Fix it so it works correctly. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/02_fix_broken_skill/fixtures/SKILL.md` (intentionally broken — missing closing `---`, no `name:` field):
```
---
description: A skill that greets the user with a custom message
version: 1.0.0

# Greeting Skill

This skill greets the user. Run the companion script `run.sh` with a name argument.

## Usage

Just say "greet <name>" and the skill will output a personalized greeting.
```

`groups/group2_openclaw_skills/02_fix_broken_skill/fixtures/run.sh` (intentionally broken — syntax error):
```bash
#!/bin/bash
# Greeting script
NAME=$1
if [ -z "$NAME" ]
    echo "Usage: ./run.sh <name>"
    exit 1
fi
echo "Hello, $NAME! Welcome to OpenClaw."
echo "Greeted $NAME at $(date)" >> greeting_log.txt
```
(Bug: missing `then` after `if [ -z "$NAME" ]`)

`groups/group2_openclaw_skills/02_fix_broken_skill/setup.sh`:
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp "$SCRIPT_DIR/fixtures/SKILL.md" "$SCRIPT_DIR/workspace/"
cp "$SCRIPT_DIR/fixtures/run.sh" "$SCRIPT_DIR/workspace/"
```

`groups/group2_openclaw_skills/02_fix_broken_skill/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="02_fix_broken_skill"

# Check 1: skill_structure — SKILL.md now has valid frontmatter with name + description + closing ---
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        if [ -n "$close_line" ]; then
            check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: script_fixed — run.sh executes without error
check2=FAIL
if [ -f "$WORKSPACE/run.sh" ]; then
    chmod +x "$WORKSPACE/run.sh" 2>/dev/null
    if bash "$WORKSPACE/run.sh" "TestUser" > /dev/null 2>&1; then
        check2=PASS
    fi
fi
echo "${TEST_ID}|script_fixed|${check2}"

# Check 3: preserves_intent — still a greeting skill
check3=FAIL
ALL_CONTENT=$(cat "$WORKSPACE/SKILL.md" "$WORKSPACE/run.sh" 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "greet|hello|welcome"; then
    check3=PASS
fi
echo "${TEST_ID}|preserves_intent|${check3}"
```

- [ ] **Step 4: Create test 03 — Bookmark Manager**

`groups/group2_openclaw_skills/03_bookmark_manager/prompt.md`:
```
Build an OpenClaw skill that manages bookmarks — add a URL with a tag, list all bookmarks, search by tag. Store bookmarks in a JSON file. Include a companion script. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/03_bookmark_manager/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="03_bookmark_manager"

# Check 1: skill_structure
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---" && \
       echo "$content" | grep -qi "name:" && \
       echo "$content" | grep -qi "description:"; then
        close_line=$(echo "$content" | grep -n "^---" | sed -n '2p' | cut -d: -f1)
        [ -n "$close_line" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_structure|${check1}"

# Check 2: companion_script — a .sh or .py file exists alongside SKILL.md
check2=FAIL
SCRIPT_FILE=$(find "$WORKSPACE" -maxdepth 1 \( -name "*.sh" -o -name "*.py" \) -type f | head -1)
if [ -n "$SCRIPT_FILE" ]; then
    check2=PASS
fi
echo "${TEST_ID}|companion_script|${check2}"

# Check 3: json_persistence — references or creates a .json file
check3=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "\.json|json\.dump|json\.load|bookmarks.*file|save.*json"; then
    check3=PASS
fi
echo "${TEST_ID}|json_persistence|${check3}"
```

- [ ] **Step 5: Verify all 3 validate scripts are valid bash**

```bash
for f in groups/group2_openclaw_skills/0{1,2,3}_*/validate.sh; do bash -n "$f"; done
```

- [ ] **Step 6: Commit**

```bash
git add groups/group2_openclaw_skills/0{1,2,3}_*
git commit -m "feat: group2 easy tier — pomodoro, fix broken skill, bookmarks"
```

---

### Task 2: Create Medium Tier — Tests 04, 05, 06

**Files:**
- Create: `groups/group2_openclaw_skills/04_weather_lookup/{prompt.md, validate.sh, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/05_github_pr_summary/{prompt.md, validate.sh, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/06_file_organizer/{prompt.md, validate.sh, setup.sh, fixtures/messy_dir/*, workspace/.gitkeep}`

- [ ] **Step 1: Create directory structure for tests 04-06**

```bash
for t in 04_weather_lookup 05_github_pr_summary 06_file_organizer; do
    mkdir -p groups/group2_openclaw_skills/$t/{fixtures,workspace}
    touch groups/group2_openclaw_skills/$t/workspace/.gitkeep
done
mkdir -p groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir
```

- [ ] **Step 2: Create test 04 — Weather Lookup**

`groups/group2_openclaw_skills/04_weather_lookup/prompt.md`:
```
Build an OpenClaw skill that looks up the current weather for a city using a weather API. It should require an API key as an environment variable and use curl to fetch data. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/04_weather_lookup/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="04_weather_lookup"

SKILL_FILE="$WORKSPACE/SKILL.md"

# Check 1: env_var_declared — frontmatter declares an API key env var
check1=FAIL
if [ -f "$SKILL_FILE" ]; then
    # Extract frontmatter (between first and second ---)
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    if echo "$FM" | grep -qiE "api.?key|WEATHER|requires.*env|env.*:"; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|env_var_declared|${check1}"

# Check 2: api_integration — skill or script uses curl with a weather API
check2=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "curl.*weather|weather.*api|openweathermap|wttr\.in|weatherapi"; then
    check2=PASS
fi
echo "${TEST_ID}|api_integration|${check2}"

# Check 3: bins_declared — frontmatter declares curl as required
check3=FAIL
if [ -f "$SKILL_FILE" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    if echo "$FM" | grep -qiE "bins.*curl|curl|requires.*bins"; then
        check3=PASS
    fi
fi
echo "${TEST_ID}|bins_declared|${check3}"
```

- [ ] **Step 3: Create test 05 — GitHub PR Summary**

`groups/group2_openclaw_skills/05_github_pr_summary/prompt.md`:
```
Build an OpenClaw skill that lists open PRs for a GitHub repo and shows a summary with title, author, and how old the PR is. It should require the gh CLI and also need a GITHUB_TOKEN env var. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/05_github_pr_summary/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="05_github_pr_summary"

SKILL_FILE="$WORKSPACE/SKILL.md"

# Check 1: declares_dependencies — frontmatter declares both gh binary AND GITHUB_TOKEN env var
check1=FAIL
if [ -f "$SKILL_FILE" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" 2>/dev/null)
    has_gh=$(echo "$FM" | grep -ciE "bins.*gh|gh|requires.*bins" || true)
    has_token=$(echo "$FM" | grep -ciE "GITHUB_TOKEN|github.*token|env.*GITHUB|requires.*env" || true)
    if [ "$has_gh" -gt 0 ] && [ "$has_token" -gt 0 ]; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|declares_dependencies|${check1}"

# Check 2: gh_commands — contains gh pr list or equivalent
check2=FAIL
ALL_CONTENT=$(cat "$WORKSPACE"/*.md "$WORKSPACE"/*.sh "$WORKSPACE"/*.py 2>/dev/null || true)
if echo "$ALL_CONTENT" | grep -qiE "gh pr list|gh pr view|gh api.*pulls"; then
    check2=PASS
fi
echo "${TEST_ID}|gh_commands|${check2}"

# Check 3: summary_format — references title, author, age/date
check3=FAIL
matches=0
echo "$ALL_CONTENT" | grep -qiE "title" && matches=$((matches+1))
echo "$ALL_CONTENT" | grep -qiE "author|creator|user" && matches=$((matches+1))
echo "$ALL_CONTENT" | grep -qiE "age|date|created|days|old|time" && matches=$((matches+1))
if [ "$matches" -ge 3 ]; then
    check3=PASS
fi
echo "${TEST_ID}|summary_format|${check3}"
```

- [ ] **Step 4: Create test 06 — File Organizer (execution-based)**

`groups/group2_openclaw_skills/06_file_organizer/prompt.md`:
```
Build an OpenClaw skill that organizes files in a directory by sorting them into subdirectories based on file extension (e.g., .pdf goes to pdf/, .jpg goes to images/). Include a companion shell script that does the actual organizing. The SKILL.md should reference the script by filename. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

Create fixture files:
```bash
echo "PDF content" > groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir/report.pdf
echo "JPG content" > groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir/photo.jpg
echo "TXT content" > groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir/notes.txt
echo "CSV content" > groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir/data.csv
echo "PY content"  > groups/group2_openclaw_skills/06_file_organizer/fixtures/messy_dir/script.py
```

`groups/group2_openclaw_skills/06_file_organizer/setup.sh`:
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace/test_dir"
cp "$SCRIPT_DIR/fixtures/messy_dir/"* "$SCRIPT_DIR/workspace/test_dir/"
```

`groups/group2_openclaw_skills/06_file_organizer/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="06_file_organizer"

# Check 1: skill_and_script — SKILL.md + companion script + SKILL.md references script
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SCRIPT_FILE=$(find "$WORKSPACE" -maxdepth 1 \( -name "*.sh" -o -name "*.py" \) ! -name "SKILL.md" -type f | head -1)
    if [ -n "$SCRIPT_FILE" ]; then
        script_name=$(basename "$SCRIPT_FILE")
        if grep -q "$script_name" "$WORKSPACE/SKILL.md" 2>/dev/null; then
            check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: organizes_files — run the script on test_dir, check files moved into subdirs
check2=FAIL
if [ -n "${SCRIPT_FILE:-}" ] && [ -d "$WORKSPACE/test_dir" ]; then
    chmod +x "$SCRIPT_FILE" 2>/dev/null
    # Try running with test_dir as argument, or from within test_dir
    (cd "$WORKSPACE" && bash "$SCRIPT_FILE" test_dir 2>/dev/null || bash "$SCRIPT_FILE" "$WORKSPACE/test_dir" 2>/dev/null || python3 "$SCRIPT_FILE" test_dir 2>/dev/null || python3 "$SCRIPT_FILE" "$WORKSPACE/test_dir" 2>/dev/null) || true

    # Count files that ended up in subdirectories (not in test_dir root)
    moved=0
    for f in report.pdf photo.jpg notes.txt data.csv script.py; do
        if find "$WORKSPACE/test_dir" -mindepth 2 -name "$f" 2>/dev/null | grep -q .; then
            moved=$((moved + 1))
        fi
    done
    [ "$moved" -ge 3 ] && check2=PASS
fi
echo "${TEST_ID}|organizes_files|${check2}"

# Check 3: no_data_loss — all 5 files still exist somewhere
check3=FAIL
found=0
for f in report.pdf photo.jpg notes.txt data.csv script.py; do
    if find "$WORKSPACE/test_dir" -name "$f" 2>/dev/null | grep -q .; then
        found=$((found + 1))
    fi
done
[ "$found" -ge 5 ] && check3=PASS
echo "${TEST_ID}|no_data_loss|${check3}"
```

- [ ] **Step 5: Verify and commit**

```bash
for f in groups/group2_openclaw_skills/0{4,5,6}_*/validate.sh; do bash -n "$f"; done
git add groups/group2_openclaw_skills/0{4,5,6}_*
git commit -m "feat: group2 medium tier — weather, github PR, file organizer"
```

---

### Task 3: Create Hard Tier — Tests 07, 08

**Files:**
- Create: `groups/group2_openclaw_skills/07_hackernews_digest/{prompt.md, validate.sh, fixtures/mock_hn_api.py, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/08_webhook_receiver/{prompt.md, validate.sh, workspace/.gitkeep}`

- [ ] **Step 1: Create directories**

```bash
for t in 07_hackernews_digest 08_webhook_receiver; do
    mkdir -p groups/group2_openclaw_skills/$t/{fixtures,workspace}
    touch groups/group2_openclaw_skills/$t/workspace/.gitkeep
done
```

- [ ] **Step 2: Create mock HN API server**

`groups/group2_openclaw_skills/07_hackernews_digest/fixtures/mock_hn_api.py`:
```python
#!/usr/bin/env python3
"""Mock HackerNews API server for testing. Stdlib only."""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

STORIES = {str(i): {"id": i, "title": f"Story {i}", "url": f"https://example.com/{i}", "score": i * 10, "by": f"user_{i}"} for i in range(1, 6)}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/v0/topstories.json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps([1, 2, 3, 4, 5]).encode())
        elif self.path.startswith("/v0/item/") and self.path.endswith(".json"):
            item_id = self.path.split("/")[-1].replace(".json", "")
            if item_id in STORIES:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(STORIES[item_id]).encode())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # suppress logs

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 18200), Handler)
    server.serve_forever()
```

- [ ] **Step 3: Create test 07 — HackerNews Digest**

`groups/group2_openclaw_skills/07_hackernews_digest/prompt.md`:
```
Build an OpenClaw skill that generates a daily digest — it should fetch top HackerNews stories, format them into a readable report, and save as an HTML file. Include a Python script that does the fetching and formatting. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/07_hackernews_digest/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="07_hackernews_digest"

MOCK_PID=""
cleanup() { [ -n "$MOCK_PID" ] && kill $MOCK_PID 2>/dev/null || true; }
trap cleanup EXIT

# Check 1: skill_and_script — SKILL.md with frontmatter + .py script exists
check1=FAIL
PY_SCRIPT=""
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---"; then
        PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
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
    for f in "$WORKSPACE"/*.py; do
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
```

- [ ] **Step 4: Create test 08 — Webhook Receiver**

`groups/group2_openclaw_skills/08_webhook_receiver/prompt.md`:
```
Build an OpenClaw skill that starts a simple webhook receiver — a lightweight Python HTTP server that listens on a configurable port, accepts POST requests, and logs each payload as a line in a JSON lines file. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/08_webhook_receiver/validate.sh`:
```bash
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
```

- [ ] **Step 5: Verify and commit**

```bash
for f in groups/group2_openclaw_skills/0{7,8}_*/validate.sh; do bash -n "$f"; done
python3 -c "import ast; ast.parse(open('groups/group2_openclaw_skills/07_hackernews_digest/fixtures/mock_hn_api.py').read())"
git add groups/group2_openclaw_skills/0{7,8}_*
git commit -m "feat: group2 hard tier part 1 — HN digest, webhook receiver"
```

---

### Task 4: Create Hard Tier — Tests 09, 10

**Files:**
- Create: `groups/group2_openclaw_skills/09_data_pipeline/{prompt.md, validate.sh, setup.sh, fixtures/posts.json, workspace/.gitkeep}`
- Create: `groups/group2_openclaw_skills/10_smart_home_controller/{prompt.md, validate.sh, setup.sh, fixtures/devices.json, workspace/.gitkeep}`

- [ ] **Step 1: Create directories**

```bash
for t in 09_data_pipeline 10_smart_home_controller; do
    mkdir -p groups/group2_openclaw_skills/$t/{fixtures,workspace}
    touch groups/group2_openclaw_skills/$t/workspace/.gitkeep
done
```

- [ ] **Step 2: Create fixtures/posts.json for test 09**

Generate a static copy of jsonplaceholder /posts (100 posts, 10 with userId=1):

```bash
python3 -c "
import json
posts = []
for i in range(1, 101):
    uid = ((i - 1) % 10) + 1
    posts.append({'userId': uid, 'id': i, 'title': f'Post {i} by user {uid}', 'body': f'Body of post {i}'})
with open('groups/group2_openclaw_skills/09_data_pipeline/fixtures/posts.json', 'w') as f:
    json.dump(posts, f, indent=2)
"
```

- [ ] **Step 3: Create test 09 — Data Pipeline**

`groups/group2_openclaw_skills/09_data_pipeline/prompt.md`:
```
Build an OpenClaw skill that runs a data pipeline: step 1 reads posts from a JSON file, step 2 filters posts where userId=1, step 3 generates a markdown summary report with post titles. Include a Python script. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/09_data_pipeline/setup.sh`:
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp "$SCRIPT_DIR/fixtures/posts.json" "$SCRIPT_DIR/workspace/"
```

`groups/group2_openclaw_skills/09_data_pipeline/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="09_data_pipeline"

# Check 1: skill_and_script — SKILL.md with frontmatter + .py script
check1=FAIL
PY_SCRIPT=""
if [ -f "$WORKSPACE/SKILL.md" ]; then
    content=$(cat "$WORKSPACE/SKILL.md")
    if echo "$content" | head -1 | grep -q "^---"; then
        PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
        [ -n "$PY_SCRIPT" ] && check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: pipeline_runs — run script, check .md file produced
check2=FAIL
MD_FILE=""
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" 2>/dev/null) || true
    MD_FILE=$(find "$WORKSPACE" -maxdepth 2 -name "*.md" ! -name "SKILL.md" ! -name "README.md" -type f | head -1)
    [ -n "$MD_FILE" ] && check2=PASS
fi
echo "${TEST_ID}|pipeline_runs|${check2}"

# Check 3: correct_filtering — output has exactly 10 posts from userId=1
check3=FAIL
if [ -n "${MD_FILE:-}" ] && [ -f "$MD_FILE" ]; then
    # Count lines containing "Post X by user 1" — should be 10
    # Posts with userId=1 are: 1, 11, 21, 31, 41, 51, 61, 71, 81, 91
    count=$(grep -ciE "post.*(1|11|21|31|41|51|61|71|81|91).*user.?1|user.?1.*post" "$MD_FILE" 2>/dev/null || echo 0)
    # Alternative: just count how many "user 1" or "userId.*1" references
    if [ "$count" -lt 5 ]; then
        # Try looser match — count title-like lines
        count=$(grep -cE "^[#*-]" "$MD_FILE" 2>/dev/null || echo 0)
        # Should have around 10 list items or headings for 10 posts
        [ "$count" -ge 8 ] && [ "$count" -le 15 ] && check3=PASS
    else
        [ "$count" -ge 8 ] && check3=PASS
    fi
fi
echo "${TEST_ID}|correct_filtering|${check3}"
```

- [ ] **Step 4: Create test 10 — Smart Home Controller**

`groups/group2_openclaw_skills/10_smart_home_controller/fixtures/devices.json`:
```json
{
  "devices": [
    {"id": "light_living", "name": "living room light", "type": "light", "state": "off"},
    {"id": "light_bedroom", "name": "bedroom light", "type": "light", "state": "off"},
    {"id": "thermo_bedroom", "name": "bedroom temperature", "type": "thermostat", "state": "20"}
  ]
}
```

`groups/group2_openclaw_skills/10_smart_home_controller/prompt.md`:
```
Build an OpenClaw skill that controls smart home devices. It should read device config from a JSON file, support commands like 'turn on living room light' and 'set bedroom temperature to 22', and maintain device state in a separate state file. Include a Python script that processes commands. OpenClaw skills use a SKILL.md file with YAML frontmatter.
```

`groups/group2_openclaw_skills/10_smart_home_controller/setup.sh`:
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp "$SCRIPT_DIR/fixtures/devices.json" "$SCRIPT_DIR/workspace/"
```

`groups/group2_openclaw_skills/10_smart_home_controller/validate.sh`:
```bash
#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="10_smart_home_controller"

# Find the Python script
PY_SCRIPT=""
for name in controller.py smart_home.py main.py run.py home.py; do
    [ -f "$WORKSPACE/$name" ] && PY_SCRIPT="$WORKSPACE/$name" && break
done
if [ -z "$PY_SCRIPT" ]; then
    PY_SCRIPT=$(find "$WORKSPACE" -maxdepth 2 -name "*.py" -type f | head -1)
fi

# Check 1: skill_and_script — SKILL.md with frontmatter (declares config) + .py script
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ] && [ -n "$PY_SCRIPT" ]; then
    FM=$(sed -n '/^---$/,/^---$/p' "$WORKSPACE/SKILL.md" 2>/dev/null)
    if echo "$FM" | grep -qiE "config|devices|require"; then
        check1=PASS
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: light_control — run "turn on living room light", check state
check2=FAIL
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" "turn on living room light" 2>/dev/null) || true

    # Find state file (anything that's not devices.json, SKILL.md, or the script)
    STATE_FILE=$(find "$WORKSPACE" -maxdepth 1 -name "*.json" ! -name "devices.json" -type f -newer "$PY_SCRIPT" 2>/dev/null | head -1)
    # Also check if devices.json was updated as state
    if [ -z "$STATE_FILE" ]; then
        STATE_FILE=$(find "$WORKSPACE" -maxdepth 1 -name "state*" -o -name "*state*" 2>/dev/null | head -1)
    fi
    if [ -z "$STATE_FILE" ]; then
        # Maybe the model uses devices.json itself as state
        STATE_FILE="$WORKSPACE/devices.json"
    fi

    if [ -f "$STATE_FILE" ] && grep -qi "on" "$STATE_FILE" 2>/dev/null; then
        check2=PASS
    fi
fi
echo "${TEST_ID}|light_control|${check2}"

# Check 3: thermostat_control — run "set bedroom temperature to 22", check state
check3=FAIL
if [ -n "$PY_SCRIPT" ]; then
    (cd "$WORKSPACE" && python3 "$PY_SCRIPT" "set bedroom temperature to 22" 2>/dev/null) || true

    if [ -f "${STATE_FILE:-}" ] && grep -q "22" "$STATE_FILE" 2>/dev/null; then
        check3=PASS
    fi
fi
echo "${TEST_ID}|thermostat_control|${check3}"
```

- [ ] **Step 5: Verify and commit**

```bash
for f in groups/group2_openclaw_skills/{09,10}_*/validate.sh; do bash -n "$f"; done
git add groups/group2_openclaw_skills/{09,10}_*
git commit -m "feat: group2 hard tier part 2 — data pipeline, smart home controller"
```

---

### Task 5: Update README and Smoke Test

**Files:**
- Modify: `README.md` — add Group 2 to test groups table
- Modify: `README_zh.md` — same

- [ ] **Step 1: Update both READMEs to list Group 2**

In both READMEs, change the test groups table to show Group 2 as "Done" and add the test list.

- [ ] **Step 2: Smoke test — run one cheap model on Group 2**

```bash
OPENCODE_GROUP=group2_openclaw_skills bash run_benchmark.sh "openrouter/qwen/qwen3-coder-flash"
```

Expected: 10 tests run, results printed, no validate.sh crashes.

- [ ] **Step 3: Fix any issues found in smoke test**

- [ ] **Step 4: Commit and push**

```bash
git add README.md README_zh.md groups/group2_openclaw_skills/
git commit -m "feat: group2 openclaw skills — 10 tests for agent skill building"
git push origin main
```
