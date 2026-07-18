#!/usr/bin/env bash
# Validates the Godot project headlessly (no display needed):
#   1. import pass  2. script/command sanity gate
# Requires GODOT_BIN pointing at a Godot 4.4 editor binary (default: godot).
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/project"

echo "== godot version =="
"$GODOT_BIN" --version

echo "== import pass =="
"$GODOT_BIN" --headless --import --path "$PROJECT_DIR"

echo "== headless checks =="
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/smoke/headless_check.gd

echo "OK"
