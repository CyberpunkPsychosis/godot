@tool
extends EditorPlugin
## AI Console: chat console + MCP server that lets AIs operate the Godot
## editor. Wires together the command registry (shared capability catalog),
## the WebSocket MCP server (external agents: Claude Code, Cursor, Cline...)
## and the bottom-panel chat dock (built-in LLM chat).

const CommandContext := preload("res://addons/ai_console/core/command_context.gd")
const Registry := preload("res://addons/ai_console/core/command_registry.gd")
const Ops := preload("res://addons/ai_console/core/editor_ops.gd")
const WSServer := preload("res://addons/ai_console/mcp/ws_server.gd")
const Protocol := preload("res://addons/ai_console/mcp/mcp_protocol.gd")
const PortFile := preload("res://addons/ai_console/mcp/port_file.gd")
const ChatDock := preload("res://addons/ai_console/chat/chat_dock.gd")
const ChatSettings := preload("res://addons/ai_console/chat/chat_settings.gd")
const LogTail := preload("res://addons/ai_console/debug/log_tail.gd")
const Downloader := preload("res://addons/ai_console/core/asset_sources/downloader.gd")

var ctx  # CommandContext
var registry  # Registry
var ops: Node
var ws_server  # WSServer
var dock  # ChatDock
var log_tail  # LogTail
var downloader: Node  # Downloader (asset pipeline HTTP + zip)
var ws_port := 0


func _enter_tree() -> void:
	var version := Engine.get_version_info()
	if version.major != 4 or version.minor < 3:
		push_error("[AI Console] Requires Godot 4.3+ (running %d.%d). Plugin disabled." % [version.major, version.minor])
		return
	ops = Ops.new()
	ops.name = "AIConsoleOps"
	add_child(ops)
	downloader = Downloader.new()
	downloader.name = "AIConsoleDownloader"
	add_child(downloader)
	ctx = CommandContext.new()
	ctx.plugin = self
	ctx.ops = ops
	registry = Registry.new()
	for error in registry.setup(ctx):
		push_error("[AI Console] " + error)
	log_tail = LogTail.new()
	dock = ChatDock.new()
	dock.name = "AIConsole"
	dock.plugin = self
	dock.registry = registry
	add_control_to_bottom_panel(dock, "AI")
	_start_mcp_server()
	print("[AI Console] Ready — %d commands registered." % registry.commands.size())


func _exit_tree() -> void:
	if ws_server != null:
		ws_server.stop()
		ws_server = null
	PortFile.clear()
	if dock != null:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null
	if ops != null:
		ops.queue_free()
		ops = null
	if downloader != null:
		downloader.queue_free()
		downloader = null


func _process(_delta: float) -> void:
	if ws_server != null:
		ws_server.poll()
	if log_tail != null:
		log_tail.poll()


func _start_mcp_server() -> void:
	if not bool(ChatSettings.get_stored("mcp_enabled")):
		print("[AI Console] MCP server disabled in settings.")
		return
	ws_server = WSServer.new()
	var protocol = Protocol.new()
	protocol.registry = registry
	ws_server.protocol = protocol
	ws_server.client_connected.connect(func(_session) -> void:
		if dock != null:
			dock.notify("External AI agent connected via MCP.", "info")
	)
	ws_server.client_disconnected.connect(func(_session) -> void:
		if dock != null:
			dock.notify("External AI agent disconnected.", "info")
	)
	ws_port = ws_server.start(int(ChatSettings.get_stored("mcp_port")))
	if ws_port > 0:
		PortFile.write(ws_port)
		if dock != null:
			dock.set_mcp_port(ws_port)
		print("[AI Console] MCP server listening on ws://127.0.0.1:%d" % ws_port)
	else:
		push_error("[AI Console] Could not bind any MCP port in 9080-9099; external agents won't be able to connect.")
