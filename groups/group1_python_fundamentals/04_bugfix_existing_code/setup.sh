#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/workspace"
cp -r "$SCRIPT_DIR/fixtures/"* "$SCRIPT_DIR/workspace/"
