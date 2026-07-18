@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "stop_running"
	description = "Stop the currently running game (if any)."
	params_schema = {"type": "object", "properties": {}}
	undoable = false


func execute(_params: Dictionary, _ctx) -> Dictionary:
	var was_playing := EditorInterface.is_playing_scene()
	if was_playing:
		EditorInterface.stop_playing_scene()
	return R.ok({"was_playing": was_playing})
