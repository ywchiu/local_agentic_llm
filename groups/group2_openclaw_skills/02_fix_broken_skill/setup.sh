#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp "$SCRIPT_DIR/fixtures/SKILL.md" "$SCRIPT_DIR/workspace/"
cp "$SCRIPT_DIR/fixtures/run.sh" "$SCRIPT_DIR/workspace/"
