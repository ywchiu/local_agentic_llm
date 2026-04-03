#!/usr/bin/env python3
"""Agent harness for agentic coding benchmarks via Google Gemini API (supports Gemma models)."""

import argparse
import json
import os
import signal
import subprocess
import sys
import time

from google import genai
from google.genai import types

SYSTEM_PROMPT = """You are a software engineer. The user will ask you to build something.
Use the provided tools to write files and run commands.
All file paths are relative to the current working directory.
Path traversal outside the working directory is not allowed.
Do not ask clarifying questions — just build what is requested.
Install any dependencies you need using pip or other package managers."""

# Tool declarations for Gemini function calling
TOOL_DECLARATIONS = [
    {
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
    {
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
    {
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
    {
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
]


def parse_args():
    parser = argparse.ArgumentParser(description="Gemini API agent harness for coding benchmarks")
    parser.add_argument("--model", required=True, help="Model name (e.g. gemma-4-31b-it)")
    parser.add_argument("--prompt", required=True, help="Path to prompt.md file")
    parser.add_argument("--workspace", required=True, help="Path to workspace directory")
    parser.add_argument("--timeout", type=int, default=300, help="Global timeout in seconds")
    parser.add_argument("--max-turns", type=int, default=50, help="Max tool-calling rounds")
    parser.add_argument("--thinking", choices=["off", "low", "medium", "high"], default="off",
                        help="Thinking/reasoning level (default: off)")
    return parser.parse_args()


def validate_path(workspace, path):
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
            command, shell=True, cwd=workspace,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
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


def run_agent(model, prompt, workspace, timeout, max_turns, thinking="off"):
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        return {"error": "GEMINI_API_KEY not set", "timed_out": False}

    client = genai.Client(api_key=api_key)

    # Build tools
    tools = types.Tool(function_declarations=TOOL_DECLARATIONS)

    # Build config
    config_kwargs = {
        "tools": [tools],
        "temperature": 0,
        "max_output_tokens": 16384,
        "system_instruction": SYSTEM_PROMPT,
    }
    if thinking != "off":
        config_kwargs["thinking_config"] = types.ThinkingConfig(
            thinking_level=thinking.upper(),
        )

    config = types.GenerateContentConfig(**config_kwargs)

    # Build initial contents
    contents = [
        types.Content(
            role="user",
            parts=[types.Part.from_text(text=prompt)],
        ),
    ]

    metrics = {
        "model": model,
        "thinking": thinking,
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

        response = None
        for attempt in range(5):
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=contents,
                    config=config,
                )
                break
            except Exception as e:
                err_str = str(e)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    # Extract retry delay if available
                    import re as _re
                    delay_match = _re.search(r'retry in (\d+)', err_str)
                    wait = int(delay_match.group(1)) + 5 if delay_match else 30
                    print(f"  Rate limited, waiting {wait}s (attempt {attempt+1}/5)...", file=sys.stderr)
                    time.sleep(wait)
                    if time.time() >= deadline:
                        metrics["timed_out"] = True
                        break
                    continue
                metrics["error"] = f"API error: {e}"
                break
        if metrics.get("error") or metrics["timed_out"] or response is None:
            if response is None and not metrics.get("error"):
                metrics["error"] = "API failed after 5 retries"
            break

        # Extract token usage from response
        if hasattr(response, 'usage_metadata') and response.usage_metadata:
            um = response.usage_metadata
            prompt_tokens = getattr(um, 'prompt_token_count', 0) or 0
            output_tokens = getattr(um, 'candidates_token_count', 0) or 0
            thinking_tokens = getattr(um, 'thinking_token_count', 0) or 0
            metrics["input_tokens"] += prompt_tokens
            metrics["output_tokens"] += output_tokens
            metrics["reasoning_tokens"] += thinking_tokens
            metrics["total_tokens"] += prompt_tokens + output_tokens

        # Check for valid response
        if not response.candidates:
            metrics["error"] = "No candidates in response"
            break

        candidate = response.candidates[0]
        parts = candidate.content.parts if candidate.content else []

        # Add assistant response to contents
        contents.append(candidate.content)

        # Check for function calls in parts
        function_calls = [p for p in parts if p.function_call]

        if not function_calls:
            # No tool calls — model is done
            break

        # Execute each function call
        function_responses = []
        for part in function_calls:
            if time.time() >= deadline:
                metrics["timed_out"] = True
                break

            metrics["tool_calls"] += 1
            fc = part.function_call
            name = fc.name
            arguments = dict(fc.args) if fc.args else {}

            print(f"  tool: {name}({', '.join(f'{k}={repr(v)[:60]}' for k,v in arguments.items())})", file=sys.stderr)
            result = execute_tool(workspace, name, arguments)

            function_responses.append(
                types.Part.from_function_response(
                    name=name,
                    response={"result": str(result)[:5000]},
                )
            )

        if metrics["timed_out"]:
            break

        # Send function responses back
        contents.append(types.Content(role="user", parts=function_responses))

    else:
        metrics["max_turns_reached"] = True

    return metrics


def main():
    args = parse_args()

    with open(args.prompt, "r") as f:
        prompt = f.read().strip()

    workspace = os.path.realpath(args.workspace)
    os.makedirs(workspace, exist_ok=True)

    print(f"Gemini harness: model={args.model} thinking={args.thinking} timeout={args.timeout}s max_turns={args.max_turns}", file=sys.stderr)
    print(f"Workspace: {workspace}", file=sys.stderr)

    metrics = run_agent(args.model, prompt, workspace, args.timeout, args.max_turns, thinking=args.thinking)

    json.dump(metrics, sys.stdout)
    print()


if __name__ == "__main__":
    main()
