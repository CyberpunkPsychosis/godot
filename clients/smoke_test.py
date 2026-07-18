#!/usr/bin/env python3
"""Scripted MCP smoke test against a LIVE Godot editor running the AI Console.

Usage:
    pip install websockets
    # open project/ in the Godot editor first (plugin auto-starts its server)
    python clients/smoke_test.py                 # basic suite
    python clients/smoke_test.py --suite full    # scene-building suite
    python clients/smoke_test.py --url ws://127.0.0.1:9080

Discovers the port from project/.godot/ai_console_port.json when --url is not
given. Exits non-zero on any failure.
"""
import argparse
import asyncio
import json
import pathlib
import sys

try:
    import websockets
except ImportError:
    sys.exit("pip install websockets")

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent


class Client:
    def __init__(self, ws):
        self.ws = ws
        self.next_id = 0
        self.passed = 0
        self.failed = 0

    async def rpc(self, method, params=None):
        self.next_id += 1
        await self.ws.send(json.dumps({
            "jsonrpc": "2.0", "id": self.next_id,
            "method": method, "params": params or {},
        }))
        while True:
            msg = json.loads(await asyncio.wait_for(self.ws.recv(), timeout=90))
            if msg.get("id") == self.next_id:
                return msg

    async def call_tool(self, name, arguments=None):
        msg = await self.rpc("tools/call", {"name": name, "arguments": arguments or {}})
        text = msg["result"]["content"][0]["text"]
        return json.loads(text)

    def check(self, label, condition, detail=""):
        if condition:
            self.passed += 1
            print(f"  PASS {label}")
        else:
            self.failed += 1
            print(f"  FAIL {label} {detail}")


async def basic_suite(c: Client):
    print("== basic ==")
    init = await c.rpc("initialize", {
        "protocolVersion": "2025-06-18",
        "clientInfo": {"name": "smoke_test", "version": "0.1"},
        "capabilities": {},
    })
    c.check("initialize", init["result"]["serverInfo"]["name"] == "godot-ai-console", init)
    await c.ws.send(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}))

    tools = await c.rpc("tools/list")
    names = [t["name"] for t in tools["result"]["tools"]]
    c.check("tools/list has 30+ tools", len(names) >= 30, f"got {len(names)}")
    for expected in ("create_node", "get_scene_tree", "build_character_2d", "play_scene"):
        c.check(f"tool {expected} present", expected in names)

    state = await c.call_tool("get_editor_state")
    c.check("get_editor_state ok", state["ok"], state)
    print(f"  editor: godot {state['result']['godot_version']}, scene={state['result']['edited_scene']}")

    unknown = await c.call_tool("no_such_tool")
    c.check("unknown tool returns error envelope", not unknown["ok"] and unknown["error"]["code"] == "UNKNOWN_COMMAND")

    bad = await c.call_tool("create_node", {})
    c.check("schema validation rejects missing params", not bad["ok"] and bad["error"]["code"] == "SCHEMA_INVALID")


async def scene_suite(c: Client):
    print("== scene ==")
    scene = await c.call_tool("new_scene", {
        "root_type": "Node2D", "root_name": "SmokeTest",
        "save_path": "res://scenes/smoke_test.tscn",
    })
    if not scene["ok"] and scene["error"]["code"] == "DENIED_BY_USER":
        print("  SKIP scene suite (approval denied in editor)")
        return
    c.check("new_scene", scene["ok"], scene)

    created = await c.call_tool("create_node", {"type": "Sprite2D", "name": "TestSprite",
                                                "properties": {"position": [123, 45]}})
    c.check("create_node", created["ok"], created)

    tree = await c.call_tool("get_scene_tree")
    children = [child["name"] for child in tree["result"]["tree"].get("children", [])]
    c.check("node visible in scene tree", "TestSprite" in children, children)

    prop = await c.call_tool("set_property", {"path": "TestSprite", "property": "modulate", "value": "red"})
    c.check("set_property", prop["ok"] and prop["result"]["new_value"] != prop["result"]["old_value"], prop)

    missing = await c.call_tool("set_property", {"path": "Sprit2D", "property": "position", "value": [0, 0]})
    c.check("helpful NODE_NOT_FOUND error", not missing["ok"] and "TestSprite" in missing["error"]["message"], missing)

    character = await c.call_tool("build_character_2d", {"name": "SmokePlayer"})
    c.check("build_character_2d", character["ok"], character)

    deleted = await c.call_tool("delete_node", {"path": "TestSprite"})
    c.check("delete_node", deleted["ok"], deleted)

    saved = await c.call_tool("save_scene")
    c.check("save_scene", saved["ok"], saved)


def discover_url(explicit):
    if explicit:
        return explicit
    port_file = REPO_ROOT / "project" / ".godot" / "ai_console_port.json"
    if not port_file.exists():
        sys.exit(f"No --url given and {port_file} not found. Open project/ in the Godot editor first.")
    return f"ws://127.0.0.1:{json.loads(port_file.read_text())['port']}"


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="")
    parser.add_argument("--suite", choices=["basic", "full"], default="basic")
    args = parser.parse_args()
    url = discover_url(args.url)
    print(f"connecting to {url}")
    async with websockets.connect(url, max_size=8 * 1024 * 1024) as ws:
        client = Client(ws)
        await basic_suite(client)
        if args.suite == "full":
            await scene_suite(client)
        print(f"\n{client.passed} passed, {client.failed} failed")
        if client.failed:
            sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
