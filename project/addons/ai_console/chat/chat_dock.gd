@tool
extends VBoxContainer
## The AI Console bottom panel: chat with the built-in LLM, live activity log
## of every command any AI executes (built-in chat AND external MCP clients),
## and approval toasts for destructive operations.

const ChatSettings := preload("res://addons/ai_console/chat/chat_settings.gd")
const ToolLoop := preload("res://addons/ai_console/chat/tool_loop.gd")
const SettingsDialog := preload("res://addons/ai_console/chat/settings_dialog.gd")

const APPROVAL_TIMEOUT_SECONDS := 60.0

var plugin: EditorPlugin
var registry  # command_registry.gd

var tool_loop  # ToolLoop
var _status_label: Label
var _mcp_label: Label
var _messages: VBoxContainer
var _scroll: ScrollContainer
var _toasts: VBoxContainer
var _input: TextEdit
var _send_button: Button
var _stop_button: Button
var _auto_approve: CheckBox
var _settings_dialog  # SettingsDialog
var _current_assistant_label: RichTextLabel = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, 240)
	_build_ui()
	tool_loop = ToolLoop.new()
	tool_loop.registry = registry
	tool_loop.plugin = plugin
	tool_loop.text_delta.connect(_on_text_delta)
	tool_loop.run_finished.connect(_on_run_finished)
	tool_loop.run_failed.connect(_on_run_failed)
	registry.command_executed.connect(_on_command_executed)
	registry.approval_requested.connect(_on_approval_requested)
	_refresh_status()
	_append_system("AI Console ready. Chat here, or connect an external agent (Claude Code, Cursor...) over MCP — see the README. Type your request and press Enter.")


func _process(_delta: float) -> void:
	if tool_loop != null:
		tool_loop.poll()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	_status_label = Label.new()
	toolbar.add_child(_status_label)
	toolbar.add_child(VSeparator.new())
	_mcp_label = Label.new()
	toolbar.add_child(_mcp_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_auto_approve = CheckBox.new()
	_auto_approve.text = "Auto-approve"
	_auto_approve.tooltip_text = "Skip confirmation for destructive operations (deletes, overwrites)."
	_auto_approve.toggled.connect(func(pressed: bool) -> void:
		registry.auto_approve = pressed
	)
	toolbar.add_child(_auto_approve)
	var new_chat := Button.new()
	new_chat.text = "New chat"
	new_chat.pressed.connect(_on_new_chat)
	toolbar.add_child(new_chat)
	_stop_button = Button.new()
	_stop_button.text = "Stop"
	_stop_button.disabled = true
	_stop_button.pressed.connect(func() -> void:
		tool_loop.abort()
	)
	toolbar.add_child(_stop_button)
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_open_settings)
	toolbar.add_child(settings_button)
	add_child(toolbar)

	_toasts = VBoxContainer.new()
	add_child(_toasts)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_messages = VBoxContainer.new()
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 6)
	_scroll.add_child(_messages)
	add_child(_scroll)

	var input_row := HBoxContainer.new()
	_input = TextEdit.new()
	_input.custom_minimum_size = Vector2(0, 56)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "Ask the AI to build or change anything in this project... (Enter to send, Shift+Enter for newline)"
	_input.gui_input.connect(_on_input_gui)
	input_row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.pressed.connect(_send)
	input_row.add_child(_send_button)
	add_child(input_row)

	_settings_dialog = SettingsDialog.new()
	_settings_dialog.settings_saved.connect(_refresh_status)
	add_child(_settings_dialog)


func _refresh_status() -> void:
	var settings := ChatSettings.get_all()
	var provider := "Claude" if String(settings["provider"]) == "anthropic" else "OpenAI-compat"
	_status_label.text = "%s · %s" % [provider, String(settings["model"])]
	var port: int = plugin.get("ws_port") if plugin != null else 0
	_mcp_label.text = ("MCP ws://127.0.0.1:%d" % port) if port > 0 else "MCP off"


func set_mcp_port(port: int) -> void:
	_mcp_label.text = ("MCP ws://127.0.0.1:%d" % port) if port > 0 else "MCP off"


# --- chat flow ---------------------------------------------------------------


func _on_input_gui(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.shift_pressed \
			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_send()


func _send() -> void:
	var text := _input.text.strip_edges()
	if text == "" or tool_loop.busy:
		return
	var settings := ChatSettings.get_all()
	if String(settings["api_key"]) == "":
		notify("No API key configured. Open Settings (or set the ANTHROPIC_API_KEY / OPENAI_API_KEY environment variable). External MCP agents like Claude Code work without this.", "warning")
		_settings_dialog.open()
		return
	_input.text = ""
	_append_message("You", text, Color(0.55, 0.75, 1.0))
	_current_assistant_label = null
	_send_button.disabled = true
	_stop_button.disabled = false
	tool_loop.run(text, settings)


func _on_text_delta(text: String) -> void:
	if _current_assistant_label == null:
		_current_assistant_label = _append_message("AI", "", Color(0.7, 1.0, 0.75))
	_current_assistant_label.add_text(text)
	_scroll_to_bottom()


func _on_run_finished(reason: String) -> void:
	_send_button.disabled = false
	_stop_button.disabled = true
	_current_assistant_label = null
	if reason == "max_iterations":
		_append_system("Stopped after the per-message tool budget (25 calls). Say 'continue' to keep going.")
	elif reason == "aborted":
		_append_system("Stopped.")


func _on_run_failed(message: String) -> void:
	_send_button.disabled = false
	_stop_button.disabled = true
	_current_assistant_label = null
	notify("LLM request failed: " + message, "error")


func _on_new_chat() -> void:
	if tool_loop.busy:
		tool_loop.abort()
	tool_loop.reset()
	for child in _messages.get_children():
		child.queue_free()
	_append_system("New conversation started (editor state is re-read on the next message).")


func _on_open_settings() -> void:
	_settings_dialog.open()


# --- activity log (both built-in chat and external MCP clients) --------------


func _on_command_executed(command_name: String, params: Dictionary, result: Dictionary) -> void:
	var args := JSON.stringify(params)
	if args.length() > 120:
		args = args.left(120) + "…"
	var ok: bool = result.get("ok", false)
	var line := "🔧 %s %s → %s" % [command_name, args, "ok" if ok else String(result.get("error", {}).get("code", "error"))]
	var label := _append_message("", line, Color(0.6, 0.6, 0.6) if ok else Color(1.0, 0.55, 0.5))
	label.add_theme_font_size_override("normal_font_size", 12)


func notify(message: String, level: String = "info") -> void:
	var color := Color(0.8, 0.8, 0.85)
	if level == "warning":
		color = Color(1.0, 0.85, 0.4)
	elif level == "error":
		color = Color(1.0, 0.5, 0.45)
	_append_message("•", message, color)
	if plugin != null:
		plugin.make_bottom_panel_item_visible(self)


# --- approval toasts ---------------------------------------------------------


func _on_approval_requested(request: Dictionary) -> void:
	var toast := PanelContainer.new()
	var row := HBoxContainer.new()
	var label := Label.new()
	var args := JSON.stringify(request["params"])
	if args.length() > 160:
		args = args.left(160) + "…"
	label.text = "AI wants to run %s %s" % [request["command"], args]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var approval = request["approval"]
	var allow := Button.new()
	allow.text = "Allow"
	var deny := Button.new()
	deny.text = "Deny"
	allow.pressed.connect(func() -> void:
		approval.resolve({"approved": true})
		toast.queue_free()
	)
	deny.pressed.connect(func() -> void:
		approval.resolve({"approved": false})
		toast.queue_free()
	)
	row.add_child(allow)
	row.add_child(deny)
	toast.add_child(row)
	_toasts.add_child(toast)
	if plugin != null:
		plugin.make_bottom_panel_item_visible(self)
	var timer := get_tree().create_timer(APPROVAL_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(toast):
			approval.resolve({"approved": false})
			toast.queue_free()
	)


# --- message rendering -------------------------------------------------------


func _append_message(sender: String, text: String, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.selection_enabled = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("default_color", color)
	if sender != "":
		label.add_text("[%s] " % sender)
	label.add_text(text)
	_messages.add_child(label)
	_scroll_to_bottom()
	return label


func _append_system(text: String) -> void:
	_append_message("•", text, Color(0.65, 0.65, 0.7))


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
