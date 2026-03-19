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


def exec_write_file(workspace, path, content):
    resolved, err = validate_path(workspace, path)
    if err:
        return err
    os.makedirs(os.path.dirname(resolved), exist_ok=True)
    with open(resolved, "w") as f:
        f.write(content)
    return f"File written: {path} ({len(content)} bytes)"


def exec_read_file(workspace, path):
    resolved, err = validate_path(workspace, path)
    if err:
        return err
    if not os.path.isfile(resolved):
        return f"Error: file '{path}' not found"
    with open(resolved, "r") as f:
        return f.read()


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
