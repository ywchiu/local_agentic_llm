# Custom Agent Harness Design

**Date**: 2026-03-19
**Status**: Draft
**Problem**: opencode produces 0-byte workspaces for many models, biasing benchmark results toward models that happen to be compatible with opencode's tool interface.

## Goal

Replace opencode with a minimal, model-agnostic agent harness that gives every model the same standardized tool interface via OpenRouter. Plug into existing benchmark infrastructure (prompts, validate scripts, results format).

## Architecture

### Core Loop (`agent_harness.py`)

Single Python script (~200 lines). Uses OpenRouter `/chat/completions` with tool use.

```
1. Read prompt from prompt.md
2. Send to OpenRouter with system prompt + 4 tools
3. Model responds with tool calls and/or text
4. Execute each tool call in workspace, return results
5. Repeat until: model stops calling tools OR timeout
6. Return token/cost metrics
```

### Tools

Four tools offered to every model identically:

| Tool | Parameters | Description |
|------|-----------|-------------|
| `write_file` | `path: str`, `content: str` | Write/overwrite file. Path relative to workspace. Creates parent directories automatically. |
| `read_file` | `path: str` | Read file contents. Path relative to workspace. |
| `run_command` | `command: str` | Run shell command in workspace dir. Returns stdout+stderr. Per-command timeout: 60s. Output truncated to first 5K + last 5K chars if over 10K. |
| `list_files` | `path: str` (optional, default `.`) | List files and directories. Path relative to workspace. |

All paths are resolved relative to workspace and validated — `../` traversal is blocked with an error returned to the model.

`run_command` uses `subprocess.Popen` with a process group (`os.setsid`). On per-command timeout or global timeout, the entire process group is killed via `os.killpg`.

### System Prompt

```
You are a software engineer. The user will ask you to build something.
Use the provided tools to write files and run commands.
All file paths are relative to the current working directory.
Path traversal outside the working directory is not allowed.
Do not ask clarifying questions — just build what is requested.
Install any dependencies you need using pip or other package managers.
```

### Generation Parameters

Sent with every API request for consistency across models:
- `max_tokens`: 16384
- `temperature`: 0
- `max_turns`: 50 (loop exit if model makes 50+ tool-calling rounds)

### CLI Interface

```bash
python3 agent_harness.py \
  --model "openrouter/z-ai/glm-5" \
  --prompt "path/to/prompt.md" \
  --workspace "path/to/workspace/" \
  --timeout 300 \
  --max-turns 50
```

The harness strips the `openrouter/` prefix from model names before sending to the OpenRouter API (which expects e.g. `z-ai/glm-5`).

**Output** (JSON to stdout):
```json
{
  "model": "openrouter/z-ai/glm-5",
  "cost": 0.0234,
  "input_tokens": 15000,
  "output_tokens": 2500,
  "reasoning_tokens": 0,
  "total_tokens": 17500,
  "tool_calls": 12,
  "turns": 5,
  "timed_out": false,
  "error": null
}
```

### Integration with run_benchmark.sh

Replace the opencode call:

```bash
# Before (opencode)
run_with_timeout "$TIMEOUT" opencode run \
    -m "$model" --dir "$abs_workspace" "$prompt" \
    > "$opencode_log" 2>&1 || true

# After (agent_harness.py)
harness_output=$(python3 "$SCRIPT_DIR/agent_harness.py" \
    --model "$model" \
    --prompt "$prompt_file" \
    --workspace "$abs_workspace" \
    --timeout "$TIMEOUT" \
    2>"$opencode_log") || true
```

Token/cost data is extracted from the harness JSON output instead of from opencode session exports. The session-based token extraction code (`get_session_ids`, `extract_session_tokens`) is removed.

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Global timeout (300s default) | `threading.Timer` fires, kills any running subprocess process group, exits loop. `timed_out: true` in output. |
| Per-command timeout (60s) | `subprocess.Popen` killed after 60s. Error returned to model: "Command timed out after 60s". Model can retry or adapt. |
| Max turns reached (50 default) | Loop exits. `max_turns_reached: true` in output. |
| Model returns only text (no tool calls) | Loop exits. Score depends on what's in workspace. |
| Bad file path (`../etc/passwd`) | Return error string to model, let it retry. |
| API error (429, 500, etc.) | Exponential backoff, 3 retries. After 3 failures, abort with `error` field set. |
| Malformed tool call | Return error to model describing the issue. |

### Dependencies

- `requests` (Python, for OpenRouter API calls)
- `OPENROUTER_API_KEY` environment variable

No other dependencies. No opencode, no vendor SDKs.

## What Changes

| Component | Before | After |
|-----------|--------|-------|
| Model execution | `opencode run` | `python3 agent_harness.py` |
| Token tracking | opencode session export | Harness JSON output |
| Tool interface | opencode's internal tools | 4 standardized tools via OpenRouter |
| Dependencies | opencode CLI | Python `requests` |

## What Stays the Same

- `prompt.md` files — unchanged
- `validate.sh` scripts — unchanged (including port fixes)
- `setup.sh` scripts — unchanged (run by `run_benchmark.sh` before each harness invocation)
- `models.txt` — unchanged (harness strips `openrouter/` prefix automatically)
- `results/` directory structure — unchanged
- Result file format — unchanged
- Comparison table output — unchanged

## Token/Cost Tracking

Token counts are **cumulative across all API requests** in the session. Each OpenRouter response includes a `usage` object; the harness sums `prompt_tokens` and `completion_tokens` across all turns. Cost is read from OpenRouter's response (the `usage` object or `x-openrouter-cost` header) and summed across turns.
