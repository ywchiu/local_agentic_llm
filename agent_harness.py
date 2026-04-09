#!/usr/bin/env python3
"""Minimal agent harness for agentic coding benchmarks via OpenRouter."""

import argparse
import json
import os
import re
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

SYSTEM_PROMPT_PROMPT_TOOLS = """You are a software engineer. The user will ask you to build something.
You have the following tools available. To call a tool, output a JSON block wrapped in <tool_call> tags:

<tool_call>
{"name": "write_file", "arguments": {"path": "relative/file/path", "content": "file content here"}}
</tool_call>

<tool_call>
{"name": "read_file", "arguments": {"path": "relative/file/path"}}
</tool_call>

<tool_call>
{"name": "run_command", "arguments": {"command": "shell command here"}}
</tool_call>

<tool_call>
{"name": "list_files", "arguments": {"path": "."}}
</tool_call>

Tools:
- write_file: Write or overwrite a file. Creates parent directories automatically. Path is relative to workspace.
- read_file: Read the contents of a file. Path is relative to workspace.
- run_command: Run a shell command in the workspace directory. Returns stdout and stderr. Times out after 60 seconds.
- list_files: List files and directories in the workspace or a subdirectory.

Rules:
- All file paths are relative to the current working directory.
- Path traversal outside the working directory is not allowed.
- Do not ask clarifying questions — just build what is requested.
- Install any dependencies you need using pip or other package managers.
- You can make multiple tool calls in a single response.
- After each tool call, you will receive the result. Continue until the task is complete.
- When you are done, say "DONE" without any tool calls."""

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
    parser.add_argument("--reasoning", action="store_true", help="Enable reasoning/thinking mode")
    parser.add_argument("--prompt-tools", action="store_true", help="Use prompt-based tool calling (for models without native tool support)")
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


def _try_parse_json(text):
    """Try to parse JSON with increasingly aggressive fixups."""
    # Attempt 1: parse as-is
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Attempt 2: fix trailing commas
    cleaned = re.sub(r',\s*}', '}', text)
    cleaned = re.sub(r',\s*]', ']', cleaned)
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # Attempt 3: fix single-quote escapes (\' -> ') inside JSON strings
    # The model sometimes writes \' which is invalid JSON (only \" is valid)
    cleaned2 = cleaned.replace("\\'", "'")
    try:
        return json.loads(cleaned2)
    except json.JSONDecodeError:
        pass

    # Attempt 4: structural extraction — pull out name and content/path/command
    # For write_file: extract name, path, and content between known markers
    name_match = re.search(r'"name"\s*:\s*"(\w+)"', text)
    if not name_match:
        return None

    name = name_match.group(1)
    if name == "write_file":
        path_match = re.search(r'"path"\s*:\s*"([^"]+)"', text)
        # Content is everything between "content": " and the closing "}}
        content_match = re.search(r'"content"\s*:\s*"(.*)', text, re.DOTALL)
        if path_match and content_match:
            raw_content = content_match.group(1)
            # Strip trailing "}} or similar
            raw_content = re.sub(r'"\s*}\s*}\s*$', '', raw_content)
            # Unescape common sequences
            content = raw_content.replace('\\n', '\n').replace('\\"', '"').replace("\\'", "'").replace('\\t', '\t').replace('\\\\', '\\')
            return {"name": name, "arguments": {"path": path_match.group(1), "content": content}}
    elif name == "run_command":
        cmd_match = re.search(r'"command"\s*:\s*"((?:[^"\\]|\\.)*)"', text)
        if cmd_match:
            cmd = cmd_match.group(1).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
            return {"name": name, "arguments": {"command": cmd}}
    elif name == "read_file":
        path_match = re.search(r'"path"\s*:\s*"([^"]+)"', text)
        if path_match:
            return {"name": name, "arguments": {"path": path_match.group(1)}}
    elif name == "list_files":
        path_match = re.search(r'"path"\s*:\s*"([^"]*)"', text)
        return {"name": name, "arguments": {"path": path_match.group(1) if path_match else "."}}

    return None


def parse_tool_calls_from_text(text):
    """Extract tool calls from <tool_call>...</tool_call> blocks in model text output."""
    pattern = r'<tool_call>\s*(.*?)\s*</tool_call>'
    matches = re.findall(pattern, text, re.DOTALL)
    calls = []
    for match in matches:
        data = _try_parse_json(match)
        if data:
            name = data.get("name", "")
            arguments = data.get("arguments", {})
            if name:
                calls.append({"name": name, "arguments": arguments})
        else:
            print(f"  Warning: could not parse tool call: {match[:200]}", file=sys.stderr)
    return calls


API_URL = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/") + "/chat/completions"

def call_api(model, messages, api_key, reasoning=False, use_native_tools=True):
    """Call OpenRouter API. Returns (response_json, cost, error)."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": 16384,
        "temperature": 0,
    }
    if use_native_tools:
        payload["tools"] = TOOLS
    if reasoning:
        payload["reasoning"] = {"effort": "high"}
        payload["include_reasoning"] = True
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


def run_agent(model, prompt, workspace, timeout, max_turns, reasoning=False, prompt_tools=False):
    api_key = os.environ.get("OPENROUTER_API_KEY", "") or "EMPTY"

    # Strip openrouter/ prefix for API
    api_model = model.removeprefix("openrouter/")

    use_native_tools = not prompt_tools
    system_prompt = SYSTEM_PROMPT_PROMPT_TOOLS if prompt_tools else SYSTEM_PROMPT

    messages = [
        {"role": "system", "content": system_prompt},
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
        response, cost, err = call_api(api_model, messages, api_key, reasoning=reasoning, use_native_tools=use_native_tools)
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

        if prompt_tools:
            # Prompt-based tool calling: parse tool calls from text content
            content = message.get("content", "") or ""
            messages.append({"role": "assistant", "content": content})

            tool_calls = parse_tool_calls_from_text(content)
            if not tool_calls:
                break  # Model is done (no tool calls found)

            # Execute each tool call and collect results
            results = []
            for tc in tool_calls:
                if time.time() >= deadline:
                    metrics["timed_out"] = True
                    break

                metrics["tool_calls"] += 1
                name = tc["name"]
                arguments = tc["arguments"]
                print(f"  tool: {name}({', '.join(f'{k}={repr(v)[:60]}' for k,v in arguments.items())})", file=sys.stderr)
                result = execute_tool(workspace, name, arguments)
                results.append(f"<tool_result>\n{{'name': '{name}', 'result': {json.dumps(str(result)[:2000])} }}\n</tool_result>")

            if metrics["timed_out"]:
                break

            # Send all results back as a user message
            results_text = "\n\n".join(results)
            messages.append({"role": "user", "content": f"Tool results:\n\n{results_text}\n\nContinue with the task. If done, say DONE."})
        else:
            # Native tool calling mode
            messages.append(message)

            tool_calls = message.get("tool_calls")
            if not tool_calls:
                break  # Model is done

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

    mode = "prompt-tools" if args.prompt_tools else "native-tools"
    if args.reasoning:
        mode += "+reasoning"
    print(f"Agent harness: model={args.model} mode={mode} timeout={args.timeout}s max_turns={args.max_turns}", file=sys.stderr)
    print(f"Workspace: {workspace}", file=sys.stderr)

    metrics = run_agent(args.model, prompt, workspace, args.timeout, args.max_turns, reasoning=args.reasoning, prompt_tools=args.prompt_tools)

    # Output JSON to stdout
    json.dump(metrics, sys.stdout)
    print()  # trailing newline


if __name__ == "__main__":
    main()
