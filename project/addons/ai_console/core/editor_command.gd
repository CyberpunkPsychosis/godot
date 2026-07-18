@tool
extends RefCounted
## Base class for all AI Console editor commands.
##
## Subclasses live under addons/ai_console/commands/** (one file per command,
## auto-discovered by the registry) and must set the metadata fields in _init()
## and override execute().

const R := preload("res://addons/ai_console/core/command_result.gd")

## Unique tool name exposed to MCP clients and the built-in chat (snake_case).
var name: String = ""
## LLM-facing description: imperative, concrete, mentions defaults and caveats.
var description: String = ""
## JSON Schema (draft-07 subset) for parameters. See core/json_schema.gd.
var params_schema: Dictionary = {"type": "object", "properties": {}}
## When true the command wraps its mutations in an EditorUndoRedoManager action.
var undoable: bool = true
## When true the command requires user approval (unless auto-approve is on).
var destructive: bool = false
## When true execute() may return {"__pending": AsyncResult} and resolve later.
var long_running: bool = false


## Override for commands whose destructiveness depends on the params
## (e.g. delete_node is only guarded when removing a whole subtree).
func is_destructive(_params: Dictionary, _ctx) -> bool:
	return destructive


func execute(_params: Dictionary, _ctx) -> Dictionary:
	return R.err("NOT_IMPLEMENTED", "Command '%s' is not implemented." % name)
