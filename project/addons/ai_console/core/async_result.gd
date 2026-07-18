@tool
extends RefCounted
## Completion handle for long-running or approval-gated commands.
## Commands return {"__pending": AsyncResult}; callers either connect to
## `resolved` (MCP sessions) or `await async.resolved` (chat tool loop).

signal resolved(result: Dictionary)

var is_resolved := false
var result: Dictionary = {}


func resolve(res: Dictionary) -> void:
	if is_resolved:
		return
	is_resolved = true
	result = res
	resolved.emit(res)
