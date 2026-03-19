# Group 2: OpenClaw Skill Building — Design Spec

**Date:** 2026-03-20
**Status:** Approved
**Goal:** Test whether models can build working OpenClaw skills of increasing complexity — from simple markdown-only skills to multi-file agent automations with execution-based validation.

## Context

OpenClaw is the viral open-source AI agent framework (60K+ GitHub stars). Its skill system is simple: a directory with a `SKILL.md` file containing YAML frontmatter + markdown instructions. Skills can declare dependencies (env vars, CLI binaries, config files) and include companion scripts.

This test group evaluates whether LLMs can build real, functional OpenClaw skills when given a vague prompt and minimal context about the format.

## Prompt Style

Each prompt includes one hint: "OpenClaw skills use a SKILL.md file with YAML frontmatter." The model must figure out the correct structure, frontmatter fields, and implementation approach.

## Dependency Policy

- Validation scripts (`validate.sh`) use only Python stdlib and common CLI tools (bash, grep, curl, python3).
- Mock API servers use Python stdlib only (`http.server`, `json`). No Flask/third-party.
- Models are free to install packages via `pip` in their workspace during the run (same as Group 1).

## Tests

### Easy Tier (01-03)

**01 — Pomodoro Timer**
- Prompt: "Build an OpenClaw skill that tracks pomodoro work sessions. It should let you start a timer, check remaining time, and log completed sessions to a file. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: None
- Checks:
  1. `skill_structure`: SKILL.md exists with valid YAML frontmatter (name, description)
  2. `has_timer_logic`: SKILL.md or companion script contains timer/pomodoro logic (start, check, log keywords)
  3. `session_logging`: Mentions or implements writing completed sessions to a log file

**02 — Fix Broken Skill**
- Prompt: "There's a broken OpenClaw skill in this directory. The SKILL.md has formatting issues and the companion script has a bug. Fix it so it works correctly. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: `fixtures/broken_skill/` — a SKILL.md with malformed frontmatter (missing `---` closer, no `name:` field) and a `run.sh` that has a syntax error
- Setup: `setup.sh` copies fixtures into workspace
- Checks:
  1. `skill_structure`: SKILL.md now has valid YAML frontmatter (name, description, opening and closing `---`)
  2. `script_fixed`: `run.sh` executes without error (exit code 0)
  3. `preserves_intent`: The fixed skill still relates to the original purpose (grep for key terms from original)

**03 — Bookmark Manager**
- Prompt: "Build an OpenClaw skill that manages bookmarks — add a URL with a tag, list all bookmarks, search by tag. Store bookmarks in a JSON file. Include a companion script. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: None
- Checks:
  1. `skill_structure`: SKILL.md exists with valid YAML frontmatter (name, description)
  2. `companion_script`: A .sh or .py script file exists alongside SKILL.md
  3. `json_persistence`: Script creates/uses a .json file for storage (run script with add command, check .json exists)

### Medium Tier (04-06)

**04 — Weather Lookup**
- Prompt: "Build an OpenClaw skill that looks up the current weather for a city using a weather API. It should require an API key as an environment variable and use curl to fetch data. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: None (structural validation only — no live API calls)
- Checks:
  1. `env_var_declared`: SKILL.md YAML frontmatter declares an API key env var in a `requires` or `metadata` section
  2. `api_integration`: SKILL.md or companion script contains `curl` command referencing a weather API URL
  3. `bins_declared`: SKILL.md YAML frontmatter declares `curl` as required binary (requires.bins or similar)

**05 — GitHub PR Summary**
- Prompt: "Build an OpenClaw skill that lists open PRs for a GitHub repo and shows a summary with title, author, and how old the PR is. It should require the gh CLI and also need a GITHUB_TOKEN env var. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: None (structural validation only)
- Checks:
  1. `declares_dependencies`: SKILL.md frontmatter declares both `gh` binary AND `GITHUB_TOKEN` env var
  2. `gh_commands`: SKILL.md or script contains `gh pr list` or equivalent gh CLI commands
  3. `summary_format`: Skill instructions/script reference title, author, and age/date for PRs

**06 — File Organizer** (execution-based)
- Prompt: "Build an OpenClaw skill that organizes files in a directory by sorting them into subdirectories based on file extension (e.g., .pdf goes to pdf/, .jpg goes to images/). Include a companion shell script that does the actual organizing. The SKILL.md should reference the script by filename. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: `fixtures/messy_dir/` containing: `report.pdf`, `photo.jpg`, `notes.txt`, `data.csv`, `script.py`
- Setup: `setup.sh` copies `fixtures/messy_dir/` into `workspace/test_dir/`
- Checks:
  1. `skill_and_script`: SKILL.md exists with valid frontmatter AND a companion .sh/.py script exists AND SKILL.md references the script filename
  2. `organizes_files`: Running the script on `workspace/test_dir/` creates subdirectories and moves files (at least 3 of 5 files correctly sorted)
  3. `no_data_loss`: All 5 original files still exist somewhere in the directory tree (none deleted)

### Hard Tier (07-10)

**07 — HackerNews Digest** (execution-based)
- Prompt: "Build an OpenClaw skill that generates a daily digest — it should fetch top HackerNews stories, format them into a readable report, and save as an HTML file. Include a Python script that does the fetching and formatting. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: `fixtures/mock_hn_api.py` — stdlib HTTP server on port 18200 that serves:
  - `GET /v0/topstories.json` → `[1, 2, 3, 4, 5]`
  - `GET /v0/item/{id}.json` → `{"id": N, "title": "Story N", "url": "https://example.com/N", "score": N*10, "by": "user_N"}`
- Validation protocol:
  1. Start mock API: `python3 fixtures/mock_hn_api.py &`
  2. Patch the skill's script to use `http://localhost:18200` instead of the real HN API URL (sed replace)
  3. Run the script
  4. Kill mock API
  5. Check output
- Checks:
  1. `skill_and_script`: SKILL.md with valid frontmatter + a .py script exists
  2. `produces_html`: Running the script produces an .html file in the workspace
  3. `html_has_stories`: The HTML file contains at least 3 story titles ("Story 1", "Story 2", etc.) and links

**08 — Webhook Receiver** (execution-based)
- Prompt: "Build an OpenClaw skill that starts a simple webhook receiver — a lightweight Python HTTP server that listens on a configurable port, accepts POST requests, and logs each payload as a line in a JSON lines file. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: None
- Validation protocol (same lifecycle pattern as Group 1 test 06):
  1. Find and start the Python server script (try common names: server.py, webhook.py, app.py, receiver.py)
  2. Patch port to 18201 via sed (same pattern as Group 1 port patching)
  3. Wait 3s, verify server responds
  4. POST a test JSON payload via curl
  5. Kill server
  6. Check log file
- Checks:
  1. `skill_and_server`: SKILL.md with valid frontmatter + a .py server script exists
  2. `server_starts`: Server starts and responds on the patched port
  3. `logs_payload`: After POSTing `{"event": "test", "data": "hello"}`, a log file contains "test" and "hello"

**09 — Data Pipeline** (execution-based)
- Prompt: "Build an OpenClaw skill that runs a data pipeline: step 1 reads posts from a JSON file, step 2 filters posts where userId=1, step 3 generates a markdown summary report with post titles. Include a Python script. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: `fixtures/posts.json` — static copy of jsonplaceholder /posts (100 posts, 10 with userId=1)
- Setup: `setup.sh` copies `fixtures/posts.json` into workspace
- Checks:
  1. `skill_and_script`: SKILL.md with valid frontmatter + a .py script exists
  2. `pipeline_runs`: Running the script produces a .md file
  3. `correct_filtering`: Output markdown contains exactly 10 post titles (all from userId=1), verified by checking title count

**10 — Smart Home Controller** (execution-based)
- Prompt: "Build an OpenClaw skill that controls smart home devices. It should read device config from a JSON file, support commands like 'turn on living room light' and 'set bedroom temperature to 22', and maintain device state in a separate state file. Include a Python script that processes commands. OpenClaw skills use a SKILL.md file with YAML frontmatter."
- Fixtures: `fixtures/devices.json`:
  ```json
  {
    "devices": [
      {"id": "light_living", "name": "living room light", "type": "light", "state": "off"},
      {"id": "light_bedroom", "name": "bedroom light", "type": "light", "state": "off"},
      {"id": "thermo_bedroom", "name": "bedroom temperature", "type": "thermostat", "state": "20"}
    ]
  }
  ```
- Setup: `setup.sh` copies `fixtures/devices.json` into workspace
- Validation protocol:
  1. Find the Python script (try: controller.py, smart_home.py, main.py, run.py)
  2. Run: `python3 script.py "turn on living room light"` (or similar invocation)
  3. Run: `python3 script.py "set bedroom temperature to 22"`
  4. Check state file
- Checks:
  1. `skill_and_script`: SKILL.md with valid frontmatter (declares config requirement) + .py script exists
  2. `light_control`: After "turn on living room light", state file shows living room light as "on" (grep for "on" near "living")
  3. `thermostat_control`: After "set bedroom temperature to 22", state file shows bedroom temperature as "22"

## Progressive skill_structure Validation

The `skill_structure` / first check gets progressively stricter:

| Tier | Check |
|------|-------|
| Easy (01-03) | SKILL.md exists + name + description in frontmatter |
| Medium (04-06) | Above + requires section in frontmatter (env/bins/config) |
| Hard (07-10) | Above + companion script exists + SKILL.md references it |

## Mock API Specifications

### mock_hn_api.py (test 07, port 18200)

Python stdlib `http.server`. Endpoints:
- `GET /v0/topstories.json` → `[1, 2, 3, 4, 5]`
- `GET /v0/item/1.json` → `{"id":1,"title":"Story 1","url":"https://example.com/1","score":10,"by":"user_1"}`
- (same pattern for items 2-5)

### Port convention

All mock servers and test servers use ports 18200-18210 to avoid conflicts with macOS services and other tests.

## Directory Structure

```
groups/group2_openclaw_skills/
├── 01_pomodoro_timer/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   └── workspace/
├── 02_fix_broken_skill/
│   ├── prompt.md
│   ├── validate.sh
│   ├── setup.sh
│   ├── fixtures/
│   │   └── broken_skill/
│   │       ├── SKILL.md      (malformed)
│   │       └── run.sh        (has bug)
│   └── workspace/
├── 03_bookmark_manager/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   └── workspace/
├── 04_weather_lookup/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   └── workspace/
├── 05_github_pr_summary/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   └── workspace/
├── 06_file_organizer/
│   ├── prompt.md
│   ├── validate.sh
│   ├── setup.sh
│   ├── fixtures/
│   │   └── messy_dir/
│   └── workspace/
├── 07_hackernews_digest/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   │   └── mock_hn_api.py
│   └── workspace/
├── 08_webhook_receiver/
│   ├── prompt.md
│   ├── validate.sh
│   ├── fixtures/
│   └── workspace/
├── 09_data_pipeline/
│   ├── prompt.md
│   ├── validate.sh
│   ├── setup.sh
│   ├── fixtures/
│   │   └── posts.json
│   └── workspace/
└── 10_smart_home_controller/
    ├── prompt.md
    ├── validate.sh
    ├── setup.sh
    ├── fixtures/
    │   └── devices.json
    └── workspace/
```

## Integration

- Uses same `agent_harness.py` and `run_benchmark.sh` as Group 1
- Select with: `OPENCODE_GROUP=group2_openclaw_skills ./run_benchmark.sh`
- Results in same format, 30-point scale
