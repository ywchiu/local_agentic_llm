# Agentic Vibe-Coding Test Battery

## Purpose

A test suite to evaluate the vibe-coding ability of open-source models (GLM-5 4.7, Qwen 3.5, MiniMax M2.5, Kimi K2) via OpenRouter in OpenCode. Each test gives the model a single vague prompt and validates whether the output actually works.

## Structure

```
agentic_testing/
├── run_all_validations.sh        # runs all validators, outputs scorecard
├── tests/
│   ├── 01_csv_to_json/
│   │   ├── prompt.md
│   │   ├── validate.sh
│   │   ├── fixtures/
│   │   └── workspace/
│   ├── 02_word_counter/
│   ├── 03_calculator_web/
│   ├── 04_file_organizer/
│   ├── 05_markdown_to_html/
│   ├── 06_expense_tracker_api/
│   ├── 07_url_shortener/
│   ├── 08_static_site_generator/
│   ├── 09_task_board/
│   └── 10_realtime_chat/
└── results/
```

## Tests

### Easy Tier

1. **CSV to JSON** (Script) — convert CSV to JSON, handle delimiters and missing values
2. **Word Counter** (CLI) — wc clone, multiple files, totals
3. **Calculator** (Web) — basic operations, serves in browser

### Medium Tier

4. **File Organizer** (CLI) — sort files into subfolders by extension
5. **Markdown to HTML** (CLI) — convert markdown with headers, bold, italic, links, code blocks, lists
6. **Expense Tracker API** (Web) — CRUD expenses, category totals
7. **URL Shortener** (Web) — create short URLs, redirect to originals

### Hard Tier

8. **Static Site Generator** (Script) — markdown + frontmatter → HTML with templates
9. **Task Board** (Web) — kanban with drag-and-drop, persistence across refresh
10. **Real-time Chat** (Web) — websocket-based, multiple users, instant messages

## Scoring

Each test has 3 automated checks (Pass=1, Fail=0):
- **Runs without error** — executes without crashing
- **Core functionality** — main feature works
- **Edge cases** — handles non-trivial inputs

Total: X/30 per model.

## Validation Approach

- Script/CLI tests: run directly, compare output against expected
- Web tests: start server in background, hit with curl/python requests/websocket clients, kill server after
- All validators return exit codes and structured output for the scorecard
- Validators auto-detect common file patterns (app.py, main.py, index.html, etc.)

## Workflow

1. Pick a model in OpenCode
2. Open a test's `workspace/` folder
3. Paste the prompt from `prompt.md`
4. Let the model work
5. Run `validate.sh` from the test folder
6. Repeat for all tests, then run `run_all_validations.sh` for the scorecard
