@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "get_project_setting"
	description = "Read a project setting by full path, e.g. application/run/main_scene, display/window/size/viewport_width, physics/2d/default_gravity."
	params_schema = {
		"type": "object",
		"properties": {
			"setting": {"type": "string"},
		},
		"required": ["setting"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var setting := String(params["setting"])
	if not ProjectSettings.has_setting(setting):
		return R.ok({"setting": setting, "exists": false})
	return R.ok({
		"setting": setting,
		"exists": true,
		"value": Codec.encode(ProjectSettings.get_setting(setting)),
	})
