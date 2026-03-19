#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace/test_dir"
cp "$SCRIPT_DIR/fixtures/messy_dir/"* "$SCRIPT_DIR/workspace/test_dir/"
