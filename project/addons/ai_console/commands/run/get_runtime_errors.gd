@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "get_runtime_errors"
	description = "Return errors captured from the running game's log (script errors, engine errors). Use after play_scene to diagnose problems, then fix scripts/scenes and play again."
	params_schema = {
		"type": "object",
		"properties": {
			"max": {"type": "integer", "default": 50},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var tail = ctx.plugin.log_tail
	if tail == null:
		return R.err("UNAVAILABLE", "Log capture is not active.")
	return R.ok({
		"errors": tail.get_recent(int(params["max"])),
		"is_playing": EditorInterface.is_playing_scene(),
		"note": "Errors come from user://logs/godot.log of the running game.",
	})
