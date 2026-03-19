# Custom Agent Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace opencode with a model-agnostic agent harness using OpenRouter tool-use API, eliminating the 0-byte workspace bias.

**Architecture:** Single Python script (`agent_harness.py`) implements a tool-use loop: send prompt + tools to OpenRouter, execute tool calls in a sandboxed workspace, repeat until done or timeout. Integrates with existing `run_benchmark.sh` by replacing the `opencode run` call and extracting metrics from JSON output.

**Tech Stack:** Python 3, `requests` library, OpenRouter API

**Spec:** `docs/superpowers/specs/2026-03-19-custom-agent-harness-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `agent_harness.py` | Create | Core agent loop: API calls, tool execution, metrics output |
| `run_benchmark.sh` | Modify | Replace opencode invocation with agent_harness.py, simplify token extraction |

---

### Task 1: Create agent_harness.py — Tool Definitions and Path Validation

**Files:**
- Create: `agent_harness.py`

- [ ] **Step 1: Create agent_harness.py with imports, constants, and CLI argument parsing**

```python
#!/usr/bin/env python3
"""Minimal agent harness for agentic coding benchmarks via OpenRouter."""

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import requests

SYSTEM_PROMPT = """You are a software engineer. The user will ask you to build something.
Use the provided tools to write files and run commands.
All file paths are relative to the current working directory.
Path traversal outside the working directory is not allowed.
Do not ask clarifying questions — just build what is requested.
Install any dependencies you need using pip or other package managers."""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write or overwrite a file. Creates parent directories automatically. Path is relative to workspace.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative file path"},
                    "content": {"type": "string", "description": "File content to write"},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file. Path is relative to workspace.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative file path"},
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command in the workspace directory. Returns stdout and stderr. Times out after 60 seconds.",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "Shell command to execute"},
                },
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "List files and directories in the workspace or a subdirectory.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative directory path (default: '.')", "default": "."},
                },
                "required": [],
            },
        },
    },
]


def parse_args():
    parser = argparse.ArgumentParser(description="Agent harness for coding benchmarks")
    parser.add_argument("--model", required=True, help="Model name (e.g. openrouter/z-ai/glm-5)")
    parser.add_argument("--prompt", required=True, help="Path to prompt.md file")
    parser.add_argument("--workspace", required=True, help="Path to workspace directory")
    parser.add_argument("--timeout", type=int, default=300, help="Global timeout in seconds")
    parser.add_argument("--max-turns", type=int, default=50, help="Max tool-calling rounds")
    return parser.parse_args()
```

- [ ] **Step 2: Add path validation helper**

```python
def validate_path(workspace, path):
    """Resolve path relative to workspace and block traversal."""
    if not path or path.strip() == "":
        return None, "Error: empty path"
    resolved = os.path.realpath(os.path.join(workspace, path))
    ws_real = os.path.realpath(workspace)
    if resolved == ws_real:
        return None, "Error: path resolves to workspace root"
    if not resolved.startswith(ws_real + os.sep):
        return None, f"Error: path '{path}' resolves outside workspace"
    return resolved, None
```

- [ ] **Step 3: Verify file is syntactically valid**

Run: `python3 -c "import ast; ast.parse(open('agent_harness.py').read())"`
Expected: No output (valid syntax)

- [ ] **Step 4: Commit**

```bash
git add agent_harness.py
git commit -m "feat: agent_harness.py scaffold with tool defs and path validation"
```

---

### Task 2: Implement Tool Execution Functions

**Files:**
- Modify: `agent_harness.py`

- [ ] **Step 1: Add write_file executor**

```python
def exec_write_file(workspace, path, content):
    resolved, err = validate_path(workspace, path)
    if err:
        return err
    os.makedirs(os.path.dirname(resolved), exist_ok=True)
    with open(resolved, "w") as f:
        f.write(content)
    return f"File written: {path} ({len(content)} bytes)"
```

- [ ] **Step 2: Add read_file executor**

```python
def exec_read_file(workspace, path):
    resolved, err = validate_path(workspace, path)
    if err:
        return err
    if not os.path.isfile(resolved):
        return f"Error: file '{path}' not found"
    with open(resolved, "r") as f:
        return f.read()
```

- [ ] **Step 3: Add run_command executor with per-command timeout and process group cleanup**

```python
COMMAND_TIMEOUT = 60

def truncate_output(text, limit=10000):
    if len(text) <= limit:
        return text
    half = limit // 2
    return text[:half] + f"\n\n[... truncated {len(text) - limit} chars ...]\n\n" + text[-half:]

def exec_run_command(workspace, command):
    try:
        proc = subprocess.Popen(
            command,
            shell=True,
            cwd=workspace,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            preexec_fn=os.setsid,
        )
        try:
            output, _ = proc.communicate(timeout=COMMAND_TIMEOUT)
            return truncate_output(output.decode("utf-8", errors="replace"))
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            proc.wait()
            return f"Error: command timed out after {COMMAND_TIMEOUT}s"
    except Exception as e:
        return f"Error running command: {e}"
```

- [ ] **Step 4: Add list_files executor**

```python
def exec_list_files(workspace, path="."):
    resolved, err = validate_path(workspace, path)
    if err:
        return err
    if not os.path.isdir(resolved):
        return f"Error: directory '{path}' not found"
    entries = []
    for entry in sorted(os.listdir(resolved)):
        full = os.path.join(resolved, entry)
        suffix = "/" if os.path.isdir(full) else ""
        entries.append(f"{entry}{suffix}")
    return "\n".join(entries) if entries else "(empty directory)"
```

- [ ] **Step 5: Add tool dispatch function**

```python
def execute_tool(workspace, name, arguments):
    if name == "write_file":
        return exec_write_file(workspace, arguments.get("path", ""), arguments.get("content", ""))
    elif name == "read_file":
        return exec_read_file(workspace, arguments.get("path", ""))
    elif name == "run_command":
        return exec_run_command(workspace, arguments.get("command", ""))
    elif name == "list_files":
        return exec_list_files(workspace, arguments.get("path", "."))
    else:
        return f"Error: unknown tool '{name}'"
```

- [ ] **Step 6: Verify syntax**

Run: `python3 -c "import ast; ast.parse(open('agent_harness.py').read())"`
Expected: No output

- [ ] **Step 7: Commit**

```bash
git add agent_harness.py
git commit -m "feat: tool execution functions with timeout and truncation"
```

---

### Task 3: Implement the Agent Loop and API Integration

**Files:**
- Modify: `agent_harness.py`

- [ ] **Step 1: Add the API call function with retry logic**

```python
API_URL = "https://openrouter.ai/api/v1/chat/completions"

def call_api(model, messages, api_key):
    """Call OpenRouter API. Returns (response_json, cost, error)."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": messages,
        "tools": TOOLS,
        "max_tokens": 16384,
        "temperature": 0,
    }
    for attempt in range(3):
        try:
            resp = requests.post(API_URL, headers=headers, json=payload, timeout=120)
            if resp.status_code == 200:
                cost = float(resp.headers.get("x-openrouter-cost", 0))
                return resp.json(), cost, None
            if resp.status_code in (429, 500, 502, 503):
                wait = 2 ** attempt * 5
                print(f"API {resp.status_code}, retrying in {wait}s...", file=sys.stderr)
                time.sleep(wait)
                continue
            return None, 0, f"API error {resp.status_code}: {resp.text[:500]}"
        except requests.exceptions.Timeout:
            if attempt < 2:
                print(f"API timeout, retrying...", file=sys.stderr)
                continue
            return None, 0, "API request timed out after 3 attempts"
        except Exception as e:
            return None, 0, f"API request failed: {e}"
    return None, 0, "API failed after 3 retries"
```

- [ ] **Step 2: Add the main agent loop**

```python
def run_agent(model, prompt, workspace, timeout, max_turns):
    api_key = os.environ.get("OPENROUTER_API_KEY", "")
    if not api_key:
        return {"error": "OPENROUTER_API_KEY not set", "timed_out": False}

    # Strip openrouter/ prefix for API
    api_model = model.removeprefix("openrouter/")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]

    metrics = {
        "model": model,
        "cost": 0.0,
        "input_tokens": 0,
        "output_tokens": 0,
        "reasoning_tokens": 0,
        "total_tokens": 0,
        "tool_calls": 0,
        "turns": 0,
        "timed_out": False,
        "max_turns_reached": False,
        "error": None,
    }

    deadline = time.time() + timeout

    for turn in range(max_turns):
        if time.time() >= deadline:
            metrics["timed_out"] = True
            break

        metrics["turns"] = turn + 1
        response, cost, err = call_api(api_model, messages, api_key)
        if err:
            metrics["error"] = err
            break

        # Accumulate cost from response header
        metrics["cost"] += cost

        # Accumulate token usage
        usage = response.get("usage", {})
        metrics["input_tokens"] += usage.get("prompt_tokens", 0)
        metrics["output_tokens"] += usage.get("completion_tokens", 0)
        metrics["reasoning_tokens"] += usage.get("reasoning_tokens", 0)
        metrics["total_tokens"] += usage.get("prompt_tokens", 0) + usage.get("completion_tokens", 0)

        choice = response.get("choices", [{}])[0]
        message = choice.get("message", {})
        finish_reason = choice.get("finish_reason", "")

        # Add assistant message to conversation
        messages.append(message)

        # Check for tool calls
        tool_calls = message.get("tool_calls")
        if not tool_calls:
            break  # Model is done

        # Execute each tool call
        for tc in tool_calls:
            if time.time() >= deadline:
                metrics["timed_out"] = True
                break

            metrics["tool_calls"] += 1
            func = tc.get("function", {})
            name = func.get("name", "")
            try:
                arguments = json.loads(func.get("arguments", "{}"))
            except json.JSONDecodeError:
                arguments = {}
                result = f"Error: malformed arguments JSON: {func.get('arguments', '')[:200]}"
            else:
                print(f"  tool: {name}({', '.join(f'{k}={repr(v)[:60]}' for k,v in arguments.items())})", file=sys.stderr)
                result = execute_tool(workspace, name, arguments)

            messages.append({
                "role": "tool",
                "tool_call_id": tc.get("id", ""),
                "content": str(result),
            })

        if metrics["timed_out"]:
            break
    else:
        metrics["max_turns_reached"] = True

    return metrics
```

- [ ] **Step 3: Add main entry point**

```python
def main():
    args = parse_args()

    with open(args.prompt, "r") as f:
        prompt = f.read().strip()

    workspace = os.path.realpath(args.workspace)
    os.makedirs(workspace, exist_ok=True)

    print(f"Agent harness: model={args.model} timeout={args.timeout}s max_turns={args.max_turns}", file=sys.stderr)
    print(f"Workspace: {workspace}", file=sys.stderr)

    metrics = run_agent(args.model, prompt, workspace, args.timeout, args.max_turns)

    # Output JSON to stdout
    json.dump(metrics, sys.stdout)
    print()  # trailing newline


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Verify the full script is syntactically valid**

Run: `python3 -c "import ast; ast.parse(open('agent_harness.py').read())"`
Expected: No output

- [ ] **Step 5: Smoke test with --help**

Run: `python3 agent_harness.py --help`
Expected: Shows usage with --model, --prompt, --workspace, --timeout, --max-turns

- [ ] **Step 6: Commit**

```bash
git add agent_harness.py
git commit -m "feat: complete agent loop with API integration and metrics"
```

---

### Task 4: Integration Test — Run Harness Against a Real Test

**Files:**
- No file changes — testing only

- [ ] **Step 1: Test with a simple prompt against one cheap model**

Prepare a test workspace and run:

```bash
mkdir -p /tmp/harness_test
echo "write a python script that prints hello world" > /tmp/harness_test_prompt.md
python3 agent_harness.py \
    --model "openrouter/qwen/qwen3-coder-flash" \
    --prompt /tmp/harness_test_prompt.md \
    --workspace /tmp/harness_test \
    --timeout 60 \
    2>/tmp/harness_test.log
```

Expected: JSON output with metrics, `/tmp/harness_test/` contains a `.py` file, stderr log shows tool calls.

- [ ] **Step 2: Verify the generated file exists and works**

```bash
ls /tmp/harness_test/*.py
python3 /tmp/harness_test/*.py
```

Expected: A python file exists and prints "hello world" (or similar).

- [ ] **Step 3: Test against actual benchmark test 01_csv_to_json**

```bash
rm -rf groups/group1_python_fundamentals/01_csv_to_json/workspace/*
mkdir -p groups/group1_python_fundamentals/01_csv_to_json/workspace
bash groups/group1_python_fundamentals/01_csv_to_json/setup.sh 2>/dev/null || true
python3 agent_harness.py \
    --model "openrouter/qwen/qwen3-coder-flash" \
    --prompt groups/group1_python_fundamentals/01_csv_to_json/prompt.md \
    --workspace groups/group1_python_fundamentals/01_csv_to_json/workspace \
    --timeout 120 \
    2>test_harness.log
echo "---"
bash groups/group1_python_fundamentals/01_csv_to_json/validate.sh
```

Expected: JSON metrics output, then validation passes (some checks PASS).

- [ ] **Step 4: Clean up test artifacts**

```bash
rm -rf /tmp/harness_test /tmp/harness_test_prompt.md /tmp/harness_test.log test_harness.log
```

- [ ] **Step 5: Commit (no changes expected — this was testing only)**

If any bug fixes were needed during testing, commit them:

```bash
git add agent_harness.py
git commit -m "fix: agent harness fixes from integration testing"
```

---

### Task 5: Modify run_benchmark.sh to Use agent_harness.py

**Files:**
- Modify: `run_benchmark.sh`

- [ ] **Step 1: Remove opencode-specific helper functions**

Remove `get_session_ids()` (lines 70-73) and `extract_session_tokens()` (lines 76-101). Also remove `run_with_timeout()` (lines 52-56) since the harness handles its own timeout. Also remove the unused `prompt=$(cat "$prompt_file")` (line 221) and `size_kb=` computation (line 249) since neither is used after the changes.

- [ ] **Step 2: Replace the opencode execution block**

Replace lines 223-264 (from `sessions_before=` through `test_total_tokens=`) with the following. Note: this uses `$harness_log` (renamed from `$opencode_log` in Step 3):

```bash
        # Run agent harness
        echo "  │  Running agent harness..."
        start_time=$(date +%s)

        harness_json=$(python3 "$SCRIPT_DIR/agent_harness.py" \
            --model "$model" \
            --prompt "$prompt_file" \
            --workspace "$abs_workspace" \
            --timeout "$TIMEOUT" \
            2>"$harness_log") || true

        end_time=$(date +%s)
        elapsed=$((end_time - start_time))

        # Check if timed out
        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "  │  TIMED OUT after ${TIMEOUT}s"
        else
            echo "  │  Completed in $(format_time $elapsed)"
        fi

        # Measure output
        size=$(workspace_size "$workspace")

        # Extract token/cost data from harness JSON output (single python call)
        read test_cost test_input test_output test_reasoning test_total_tokens <<< \
            $(echo "$harness_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cost',0), d.get('input_tokens',0), d.get('output_tokens',0), d.get('reasoning_tokens',0), d.get('total_tokens',0))
except:
    print('0 0 0 0 0')
" 2>/dev/null || echo "0 0 0 0 0")
```

- [ ] **Step 3: Update the log file variable name for clarity**

Rename the variable on line 205 from `opencode_log` to `harness_log`:
```bash
        harness_log="$model_result_dir/${test_name}_harness.log"
```

- [ ] **Step 4: Update the banner text**

Change line 228 from `Running opencode...` to `Running agent harness...` (already done in step 2).

Also change the header banner (line 169):
```bash
echo "  Agentic Coding Benchmark (agent_harness)"
```

- [ ] **Step 5: Verify run_benchmark.sh is syntactically valid**

Run: `bash -n run_benchmark.sh`
Expected: No output (valid syntax)

- [ ] **Step 6: Commit**

```bash
git add run_benchmark.sh
git commit -m "feat: replace opencode with agent_harness.py in benchmark runner"
```

---

### Task 6: End-to-End Test — Run Full Benchmark on 1 Model, 2 Tests

**Files:**
- No file changes — testing only

- [ ] **Step 1: Run benchmark with one cheap model on two simple tests**

```bash
OPENCODE_TESTS="01_csv_to_json,02_system_aware_script" \
    bash run_benchmark.sh "openrouter/qwen/qwen3-coder-flash"
```

Expected: Comparison table printed, results saved, both tests produce non-zero output_bytes, scores appear.

- [ ] **Step 2: Verify result files were created**

```bash
ls results/openrouter_qwen_qwen3-coder-flash_*/
```

Expected: `01_csv_to_json_result.txt`, `01_csv_to_json_harness.log`, `02_system_aware_script_result.txt`, `02_system_aware_script_harness.log`

- [ ] **Step 3: Check a result file has correct format**

```bash
cat results/openrouter_qwen_qwen3-coder-flash_*/01_csv_to_json_result.txt
```

Expected: Contains `test:`, `model:`, `score:`, `time:`, `output_bytes:`, `cost:`, `input_tokens:`, `output_tokens:`, `total_tokens:`, `timed_out:`

- [ ] **Step 4: Commit any fixes**

```bash
git add agent_harness.py run_benchmark.sh
git commit -m "fix: end-to-end test fixes for benchmark integration"
```
