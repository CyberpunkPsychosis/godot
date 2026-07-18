@tool
extends RefCounted
## Anthropic Messages API adapter (streaming, tool use).
## The chat's neutral message format IS the Anthropic content-block format, so
## build_request passes messages through unchanged.

var _current_tool: Dictionary = {}
var _pending_events: Array = []


func provider_id() -> String:
	return "anthropic"


func build_request(cfg: Dictionary, system_prompt: String, messages: Array, tools: Array) -> Dictionary:
	var api_tools := []
	for tool in tools:
		api_tools.append({
			"name": tool["name"],
			"description": tool["description"],
			"input_schema": tool["inputSchema"],
		})
	return {
		"url": String(cfg["base_url"]).trim_suffix("/") + "/v1/messages",
		"headers": {
			"x-api-key": String(cfg["api_key"]),
			"anthropic-version": "2023-06-01",
		},
		"body": {
			"model": String(cfg["model"]),
			"max_tokens": int(cfg["max_tokens"]),
			"stream": true,
			"system": system_prompt,
			"messages": messages,
			"tools": api_tools,
		},
	}


func begin() -> void:
	_current_tool = {}
	_pending_events = []


## Translates one SSE JSON object into normalized events:
## {"type": "text", "text": ...} and {"type": "tool_use", "id", "name", "input"}.
func on_sse(data: Dictionary) -> Array:
	var events := []
	match String(data.get("type", "")):
		"content_block_start":
			var block: Dictionary = data.get("content_block", {})
			if String(block.get("type", "")) == "tool_use":
				_current_tool = {"id": block.get("id", ""), "name": block.get("name", ""), "json": ""}
		"content_block_delta":
			var delta: Dictionary = data.get("delta", {})
			match String(delta.get("type", "")):
				"text_delta":
					events.append({"type": "text", "text": String(delta.get("text", ""))})
				"input_json_delta":
					if not _current_tool.is_empty():
						_current_tool["json"] += String(delta.get("partial_json", ""))
		"content_block_stop":
			if not _current_tool.is_empty():
				events.append(_finalize_tool())
		"error":
			var err: Dictionary = data.get("error", {})
			events.append({"type": "error", "message": String(err.get("message", "unknown API error"))})
	return events


func finish() -> Array:
	var events := []
	if not _current_tool.is_empty():
		events.append(_finalize_tool())
	return events


func _finalize_tool() -> Dictionary:
	var input: Variant = JSON.parse_string(String(_current_tool.get("json", "")))
	if input == null or typeof(input) != TYPE_DICTIONARY:
		input = {}
	var event := {
		"type": "tool_use",
		"id": String(_current_tool.get("id", "")),
		"name": String(_current_tool.get("name", "")),
		"input": input,
	}
	_current_tool = {}
	return event
