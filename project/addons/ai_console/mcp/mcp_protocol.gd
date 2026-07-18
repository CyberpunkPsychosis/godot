@tool
extends RefCounted
## MCP (Model Context Protocol) request handler layered over JSON-RPC sessions.
## Tools-only server: initialize, tools/list, tools/call, ping.

const SUPPORTED_VERSIONS := ["2025-06-18", "2025-03-26", "2024-11-05"]
const SERVER_NAME := "godot-ai-console"
const SERVER_VERSION := "0.1.0"

var registry  # command_registry.gd


func handle(session, msg: Dictionary) -> void:
	var method := String(msg.get("method", ""))
	var id: Variant = msg.get("id")
	if method == "":
		return  # A response from the client; nothing to do.
	match method:
		"initialize":
			_initialize(session, id, msg.get("params", {}))
		"notifications/initialized":
			session.mcp_initialized = true
		"notifications/cancelled":
			pass
		"ping":
			session.send_result(id, {})
		"tools/list":
			session.send_result(id, {"tools": registry.list_tools()})
		"tools/call":
			_tools_call(session, id, msg.get("params", {}))
		_:
			if id != null:
				session.send_error(id, -32601, "Method not found: " + method)


func _initialize(session, id: Variant, params: Dictionary) -> void:
	var requested := String(params.get("protocolVersion", SUPPORTED_VERSIONS[0]))
	var version := requested if requested in SUPPORTED_VERSIONS else SUPPORTED_VERSIONS[0]
	session.client_info = params.get("clientInfo", {})
	session.send_result(id, {
		"protocolVersion": version,
		"capabilities": {"tools": {"listChanged": true}},
		"serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
		"instructions": "This server operates a LIVE Godot editor the user is looking at. " +
			"Call get_editor_state first to orient yourself, and get_scene_tree before editing a scene. " +
			"Prefer composite tools (build_character_2d, scaffold_level_2d, setup_ui_screen) for common structures. " +
			"Every scene mutation is undoable with Ctrl+Z in the editor. Save with save_scene when done. " +
			"Destructive operations may wait for in-editor user approval — calls can take up to a minute to return.",
	})


func _tools_call(session, id: Variant, params: Dictionary) -> void:
	var tool_name := String(params.get("name", ""))
	var args: Variant = params.get("arguments", {})
	if typeof(args) != TYPE_DICTIONARY:
		args = {}
	var result: Dictionary = registry.call_command(tool_name, args)
	if result.has("__pending"):
		result["__pending"].resolved.connect(func(resolved_result: Dictionary) -> void:
			session.send_result(id, _to_tool_result(resolved_result))
		)
	else:
		session.send_result(id, _to_tool_result(result))


func _to_tool_result(result: Dictionary) -> Dictionary:
	var content := [{"type": "text", "text": JSON.stringify(result)}]
	var payload: Variant = result.get("result", {})
	if typeof(payload) == TYPE_DICTIONARY and payload.has("base64_png"):
		content.append({"type": "image", "data": payload["base64_png"], "mimeType": "image/png"})
	return {"content": content, "isError": not result.get("ok", false)}
