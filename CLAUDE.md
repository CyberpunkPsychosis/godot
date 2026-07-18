# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

"Godot AI Console" — a pure-GDScript Godot 4.4 **EditorPlugin** (not an engine fork) that embeds an AI chat panel at the bottom of the Godot editor plus an MCP server, so both the built-in chat and external MCP agents (Claude Code, Cursor, Cline) can operate the editor: create nodes, build scenes, write scripts, run the game, read runtime errors. Deliverable is a Windows installer bundling the official Godot editor + this plugin.

## Commands

```bash
# Bridge tests (no Godot needed): unit + end-to-end relay
cd bridge && npm install && npm test

# GDScript syntax check without Godot (pip install gdtoolkit):
find project -name "*.gd" | xargs gdparse

# Full headless validation (needs a Godot 4.4 binary; CI does this):
GODOT_BIN=/path/to/godot bash scripts/ci_validate.sh

# Live-editor smoke test (open project/ in the Godot editor first):
pip install websockets && python clients/smoke_test.py --suite full

# Regenerate command docs:
GODOT_BIN --headless --path project --script res://tests/tools/gen_command_docs.gd
```

Engine version is pinned end-to-end (dev/CI/installer) to **4.4.1-stable** — see `GODOT_VERSION` in `.github/workflows/ci.yml` and defaults in `packaging/*.ps1`. Keep them in sync when bumping.

## Architecture

One capability catalog serves both AI channels:

```
external agent --stdio--> bridge/src/index.mjs --WS--> mcp/ws_server.gd ─┐
chat panel (chat/tool_loop.gd) --HTTPClient SSE--> LLM API --tool_use──┤
                                                                        v
                                        core/command_registry.gd (single source of truth)
                                                                        v
                                        commands/**  → EditorInterface / scene tree
```

- `project/addons/ai_console/core/command_registry.gd` — discovers commands, validates params (JSON-schema subset), gates destructive ops behind approval, emits activity signals. **Every capability is defined exactly once** here and exposed identically to MCP (`tools/list`) and the chat's tool-use loop.
- `commands/**` — one file per command, auto-discovered. A command extends `core/editor_command.gd`, sets `name`/`description`/`params_schema` (+ `undoable`/`destructive`/`long_running`) in `_init()` and implements `execute(params, ctx)`. Return via inherited `R.ok()`/`R.err()`; error messages must tell the LLM how to self-correct (list valid children/classes/etc.).
- Long-running or approval-gated calls return `{"__pending": AsyncResult}`; MCP sessions connect to `resolved`, the chat loop `await`s it. Handle both shapes when calling `registry.call_command`.
- `core/command_context.gd` — the `ctx` passed to commands. Undo pattern used everywhere: **mutate directly first**, then `begin_action()` / `record_*()` / `end_action()` (commits with `execute=false`); do/undo methods target the persistent `core/editor_ops.gd` node so history survives. Composites nest `begin_action` so one Ctrl+Z reverts everything.
- `mcp/` — TCPServer + `WebSocketPeer.accept_stream` (the only pure-GDScript way to be a WS server), polled from `plugin.gd::_process` → all editor mutations run on the main thread. Port 9080–9099 published to `.godot/ai_console_port.json` + a global registry dir (`mcp/port_file.gd`) that the bridge reads.
- `chat/` — `llm_client.gd` streams SSE via HTTPClient (HTTPRequest can't stream), splitting event blocks on **byte** boundaries before UTF-8 decode. Providers: `providers/anthropic.gd` and `providers/openai_compat.gd`; the neutral message format IS Anthropic's content-block format, the OpenAI adapter converts. Settings persist via `EditorSettings.set_project_metadata` (never in project.godot).
- `bridge/` — Node stdio↔WS relay. stdout carries ONLY JSON-RPC lines; log to stderr exclusively (stdout pollution breaks stdio MCP clients).

## Conventions

- No `class_name` in addon scripts — use `preload()` consts and path-based `extends` (deterministic under headless load).
- `const` declarations only at class level in GDScript, never inside functions.
- `@tool` on every addon script (they run inside the editor).
- Adding a command: drop a file under `commands/<domain>/`; the registry, MCP tool list, chat tools, headless check and docs generator all pick it up automatically. `project/tests/smoke/headless_check.gd` enforces name/description/schema presence.
- Node paths in command params are relative to the scene root (`.` = root, `%Name` supported) via `core/node_resolver.gd`.
- Never bind the WS server to anything but 127.0.0.1; file commands must stay inside `res://` and reject `..`.

## Verification Status Caveat

gdparse (gdtoolkit) checks syntax only. Anything touching real editor APIs must ultimately be verified by CI's headless run and the live-editor smoke test (`clients/smoke_test.py`) — a green gdparse does not prove API-level correctness.
