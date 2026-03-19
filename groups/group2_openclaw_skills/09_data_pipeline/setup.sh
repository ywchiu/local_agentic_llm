#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp "$SCRIPT_DIR/fixtures/posts.json" "$SCRIPT_DIR/workspace/"
