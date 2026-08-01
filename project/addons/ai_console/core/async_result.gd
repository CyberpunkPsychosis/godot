@tool
extends RefCounted
## Completion handle for long-running or approval-gated commands.
## Commands return {"__pending": AsyncResult}; callers either connect to
## `resolved` (MCP sessions) or `await async.settled()` (chat tool loop).
##
## Emission is DEFERRED to the end of the frame so a command that resolves
## synchronously (validation errors, stale-plugin guards...) still reaches
## listeners that connect right after the call returns. Concurrent awaiters
## must use settled(), which is safe whether or not the result landed already.

signal resolved(result: Dictionary)

var is_resolved := false
var result: Dictionary = {}


func resolve(res: Dictionary) -> void:
	if is_resolved:
		return
	is_resolved = true
	result = res
	_emit.call_deferred()


## Await-safe accessor: returns immediately when already resolved, otherwise
## waits for the (deferred) signal.
func settled() -> Dictionary:
	if is_resolved:
		return result
	return await resolved


func _emit() -> void:
	resolved.emit(result)
