@tool
extends RefCounted
## OpenAI-compatible /chat/completions adapter (streaming, tool calls).
## Covers OpenAI, DeepSeek, OpenRouter, Ollama, LM Studio and any other server
## implementing the same API — this is what makes "any other AI" work in the
## built-in chat. Converts from/to the neutral (Anthropic-style) message format.

var _tool_calls: Dictionary = {}  # index -> {id, name, json}
var _emitted: Dictionary = {}


func provider_id() -> String:
	return "openai_compat"


func build_request(cfg: Dictionary, system_prompt: String, messages: Array, tools: Array) -> Dictionary:
	var api_messages := [{"role": "system", "content": system_prompt}]
	for msg in messages:
		api_messages.append_array(_convert_message(msg))
	var api_tools := []
	for tool in tools:
		api_tools.append({
			"type": "function",
			"function": {
				"name": tool["name"],
				"description": tool["description"],
				"parameters": tool["inputSchema"],
			},
		})
	var body := {
		"model": String(cfg["model"]),
		"stream": true,
		"messages": api_messages,
	}
	if not api_tools.is_empty():
		body["tools"] = api_tools
	return {
		"url": String(cfg["base_url"]).trim_suffix("/") + "/chat/completions",
		"headers": {"Authorization": "Bearer " + String(cfg["api_key"])},
		"body": body,
	}


func _convert_message(msg: Dictionary) -> Array:
	var role := String(msg.get("role", "user"))
	var out := []
	var text_parts := []
	var tool_calls := []
	var tool_results := []
	for block in msg.get("content", []):
		match String(block.get("type", "")):
			"text":
				text_parts.append(String(block.get("text", "")))
			"tool_use":
				tool_calls.append({
					"id": String(block.get("id", "")),
					"type": "function",
					"function": {
						"name": String(block.get("name", "")),
						"arguments": JSON.stringify(block.get("input", {})),
					},
				})
			"tool_result":
				tool_results.append(block)
	if role == "assistant":
		var entry := {"role": "assistant", "content": "\n".join(PackedStringArray(text_parts))}
		if not tool_calls.is_empty():
			entry["tool_calls"] = tool_calls
		out.append(entry)
	else:
		for result in tool_results:
			out.append({
				"role": "tool",
				"tool_call_id": String(result.get("tool_use_id", "")),
				"content": String(result.get("content", "")),
			})
		if not text_parts.is_empty():
			out.append({"role": "user", "content": "\n".join(PackedStringArray(text_parts))})
	return out


func begin() -> void:
	_tool_calls = {}
	_emitted = {}


func on_sse(data: Dictionary) -> Array:
	var events := []
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		if data.has("error"):
			var err: Dictionary = data.get("error", {})
			events.append({"type": "error", "message": String(err.get("message", "unknown API error"))})
		return events
	var choice: Dictionary = choices[0]
	var delta: Dictionary = choice.get("delta", {})
	var content: Variant = delta.get("content")
	if typeof(content) == TYPE_STRING and String(content) != "":
		events.append({"type": "text", "text": String(content)})
	for call in delta.get("tool_calls", []):
		var index := int(call.get("index", 0))
		if not _tool_calls.has(index):
			_tool_calls[index] = {"id": "", "name": "", "json": ""}
		var slot: Dictionary = _tool_calls[index]
		if call.has("id"):
			slot["id"] = String(call["id"])
		var function: Dictionary = call.get("function", {})
		if function.has("name"):
			slot["name"] = String(slot["name"]) + String(function["name"])
		if function.has("arguments"):
			slot["json"] = String(slot["json"]) + String(function["arguments"])
	var finish_reason: Variant = choice.get("finish_reason")
	if finish_reason != null and String(finish_reason) != "":
		events.append_array(finish())
	return events


func finish() -> Array:
	var events := []
	var indices := _tool_calls.keys()
	indices.sort()
	for index in indices:
		if _emitted.has(index):
			continue
		_emitted[index] = true
		var slot: Dictionary = _tool_calls[index]
		var input: Variant = JSON.parse_string(String(slot["json"]))
		if input == null or typeof(input) != TYPE_DICTIONARY:
			input = {}
		var id := String(slot["id"])
		if id == "":
			id = "call_%d" % index
		events.append({"type": "tool_use", "id": id, "name": String(slot["name"]), "input": input})
	return events
