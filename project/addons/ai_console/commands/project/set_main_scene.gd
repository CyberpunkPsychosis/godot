@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "set_main_scene"
	description = "Set the project's main scene (the one that runs on play/export). Pass a .tscn path, or omit to use the currently edited scene."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Scene path; defaults to the currently edited scene."},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var path := String(params.get("path", ""))
	if path == "":
		var root: Node = ctx.scene_root()
		if root == null or root.scene_file_path == "":
			return R.err("NO_OPEN_SCENE", "No saved scene is open; pass a path or save the scene first.")
		path = root.scene_file_path
	if not FileAccess.file_exists(path):
		return R.err("FILE_NOT_FOUND", "Scene '%s' does not exist." % path)
	ProjectSettings.set_setting("application/run/main_scene", path)
	var err := ProjectSettings.save()
	if err != OK:
		return R.err("SAVE_FAILED", "Could not save project.godot (error %d)." % err)
	return R.ok({"main_scene": path})
