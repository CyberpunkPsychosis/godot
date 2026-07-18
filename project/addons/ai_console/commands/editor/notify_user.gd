@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "notify_user"
	description = "Show a message in the AI Console panel inside the editor. External agents (Claude Code, Cursor...) should use this to surface important status or questions to the user working in Godot."
	params_schema = {
		"type": "object",
		"properties": {
			"message": {"type": "string"},
			"level": {"type": "string", "enum": ["info", "warning", "error"], "default": "info"},
		},
		"required": ["message"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var dock = ctx.plugin.dock
	if dock == null:
		return R.err("UNAVAILABLE", "The AI Console panel is not available.")
	dock.notify(String(params["message"]), String(params["level"]))
	return R.ok({"shown": true})
