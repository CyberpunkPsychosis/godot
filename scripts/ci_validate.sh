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

echo "== zip extraction safety =="
if command -v python3 >/dev/null; then
  FIXTURES="$(mktemp -d)"
  python3 - "$FIXTURES" <<'EOF'
import sys, zipfile, os
fixtures = sys.argv[1]
with zipfile.ZipFile(os.path.join(fixtures, "evil.zip"), "w") as z:
    z.writestr("ok.txt", "fine")
    z.writestr("../escaped.txt", "path traversal payload")
with zipfile.ZipFile(os.path.join(fixtures, "clean.zip"), "w") as z:
    z.writestr("sub/hello.txt", "hello")
EOF
  AI_ZIP_FIXTURES="$FIXTURES" "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/smoke/zip_safety_check.gd
  rm -rf "$FIXTURES"
else
  echo "python3 missing; skipping zip fixtures"
fi

echo "OK"
