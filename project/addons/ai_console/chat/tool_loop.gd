@tool
extends RefCounted
## The built-in chat's agent loop: streams an assistant turn from the LLM,
## executes any requested tools through the shared command registry, feeds the
## results back, and repeats until the model stops asking for tools (or the
## iteration cap / Stop button intervenes).

signal text_delta(text: String)
signal turn_started
signal run_finished(reason: String)
signal run_failed(message: String)

const LLMClient := preload("res://addons/ai_console/chat/llm_client.gd")
const AnthropicProvider := preload("res://addons/ai_console/chat/providers/anthropic.gd")
const OpenAIProvider := preload("res://addons/ai_console/chat/providers/openai_compat.gd")

const MAX_ITERATIONS := 25
const TOOL_RESULT_MAX_CHARS := 4000
const HISTORY_MAX_MESSAGES := 40

var registry  # command_registry.gd
var plugin: EditorPlugin
var messages: Array = []
var busy := false

var _client  # LLMClient
var _abort := false


func poll() -> void:
	if _client != null:
		_client.poll()


func reset() -> void:
	messages.clear()


func abort() -> void:
	_abort = true
	if _client != null and _client.active:
		_client.abort()


func run(user_text: String, settings: Dictionary) -> void:
	if busy:
		run_failed.emit("A previous request is still running; press Stop first.")
		return
	busy = true
	_abort = false
	_trim_history()
	messages.append({"role": "user", "content": [{"type": "text", "text": user_text}]})
	var provider: RefCounted
	if String(settings["provider"]) == "anthropic":
		provider = AnthropicProvider.new()
	else:
		provider = OpenAIProvider.new()
	var tools: Array = registry.list_tools()
	for iteration in range(MAX_ITERATIONS):
		if _abort:
			busy = false
			run_finished.emit("aborted")
			return
		turn_started.emit()
		var turn := await _stream_turn(provider, settings, tools)
		if turn.has("error"):
			busy = false
			run_failed.emit(String(turn["error"]))
			return
		var assistant_content := []
		if String(turn["text"]) != "":
			assistant_content.append({"type": "text", "text": turn["text"]})
		for tool_use in turn["tool_uses"]:
			assistant_content.append({
				"type": "tool_use",
				"id": tool_use["id"],
				"name": tool_use["name"],
				"input": tool_use["input"],
			})
		if assistant_content.is_empty():
			assistant_content.append({"type": "text", "text": ""})
		messages.append({"role": "assistant", "content": assistant_content})
		if turn["tool_uses"].is_empty():
			busy = false
			run_finished.emit("end_turn")
			return
		var results_content := []
		for tool_use in turn["tool_uses"]:
			if _abort:
				break
			var result: Dictionary = registry.call_command(String(tool_use["name"]), tool_use["input"])
			if result.has("__pending"):
				result = await result["__pending"].resolved
			results_content.append({
				"type": "tool_result",
				"tool_use_id": tool_use["id"],
				"content": _truncate(result),
			})
		messages.append({"role": "user", "content": results_content})
	busy = false
	run_finished.emit("max_iterations")


func _stream_turn(provider, settings: Dictionary, tools: Array) -> Dictionary:
	var request: Dictionary = provider.build_request(settings, _system_prompt(), messages, tools)
	provider.begin()
	_client = LLMClient.new()
	var turn := {"text": "", "tool_uses": [], "api_error": ""}
	_client.sse_event.connect(func(data: Dictionary) -> void:
		for event in provider.on_sse(data):
			match String(event["type"]):
				"text":
					turn["text"] += String(event["text"])
					text_delta.emit(String(event["text"]))
				"tool_use":
					turn["tool_uses"].append(event)
				"error":
					turn["api_error"] = String(event["message"])
	)
	var transport_error := [""]
	_client.finished.connect(func(message: String) -> void:
		transport_error[0] = message
	)
	_client.start(String(request["url"]), request["headers"], request["body"])
	while _client.active:
		await plugin.get_tree().process_frame
	for event in provider.finish():
		if String(event["type"]) == "tool_use":
			var duplicate := false
			for existing in turn["tool_uses"]:
				if existing["id"] == event["id"]:
					duplicate = true
			if not duplicate:
				turn["tool_uses"].append(event)
	_client = null
	if transport_error[0] == "aborted":
		return {"text": turn["text"], "tool_uses": []}
	if transport_error[0] != "":
		return {"error": transport_error[0]}
	if String(turn["api_error"]) != "":
		return {"error": String(turn["api_error"])}
	return turn


func _system_prompt() -> String:
	var state := "unknown"
	var state_result: Dictionary = registry.call_command("get_editor_state", {}, true)
	if state_result.get("ok", false):
		state = JSON.stringify(state_result["result"])
	return (
		"You are the AI assistant embedded in the Godot editor's AI Console panel. " +
		"You operate the LIVE editor the user is looking at, through tools.\n\n" +
		"Current editor state: %s\n\n" % state +
		"Guidelines:\n" +
		"- Inspect before you modify: get_scene_tree for scenes, read_file for scripts.\n" +
		"- Prefer composite tools (build_character_2d, build_character_3d, scaffold_level_2d, setup_ui_screen) for common structures.\n" +
		"- Every scene mutation is undoable with Ctrl+Z; tell the user this when you make big changes.\n" +
		"- Save with save_scene after finishing a coherent set of edits.\n" +
		"- After building something playable, offer to play_scene and check wait_for_errors.\n" +
		"- Keep node names PascalCase, script files snake_case under res://scripts/.\n" +
		"- Reply in the user's language. Be concise; the panel is small."
	)


func _truncate(result: Dictionary) -> String:
	var text := JSON.stringify(result)
	if text.length() > TOOL_RESULT_MAX_CHARS:
		return text.left(TOOL_RESULT_MAX_CHARS) + "...(truncated)"
	return text


func _trim_history() -> void:
	if messages.size() <= HISTORY_MAX_MESSAGES:
		return
	# Drop oldest turns but never split an assistant(tool_use)/user(tool_result)
	# pair: keep trimming until the window starts at a plain user text message.
	while messages.size() > HISTORY_MAX_MESSAGES:
		messages.pop_front()
	while not messages.is_empty():
		var first: Dictionary = messages[0]
		var is_plain_user := String(first.get("role", "")) == "user"
		if is_plain_user:
			for block in first.get("content", []):
				if String(block.get("type", "")) == "tool_result":
					is_plain_user = false
		if is_plain_user:
			break
		messages.pop_front()
