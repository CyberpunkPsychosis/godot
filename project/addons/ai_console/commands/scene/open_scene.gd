@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "open_scene"
	description = "Open an existing .tscn scene file in the editor and make it the edited scene."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Scene path like res://scenes/main.tscn"},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path: String = params["path"]
	if not FileAccess.file_exists(path):
		return R.err("FILE_NOT_FOUND", "Scene '%s' does not exist. Use list_files to find scenes." % path)
	EditorInterface.open_scene_from_path(path)
	return R.ok({"scene_path": path})
