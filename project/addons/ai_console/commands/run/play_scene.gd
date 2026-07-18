@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "play_scene"
	description = "Run the game from the editor: mode \"current\" plays the edited scene, \"main\" plays the project main scene, \"path\" plays a specific scene. After playing, use wait_for_errors or get_runtime_errors to check for problems."
	params_schema = {
		"type": "object",
		"properties": {
			"mode": {"type": "string", "enum": ["current", "main", "path"], "default": "current"},
			"path": {"type": "string", "description": "Scene path (required for mode=path)."},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
	var mode := String(params["mode"])
	match mode:
		"current":
			var root: Node = ctx.scene_root()
			if root == null:
				return R.err("NO_OPEN_SCENE", "No scene is open to play.")
			if root.scene_file_path == "":
				return R.err("SCENE_UNSAVED", "Save the scene first (save_scene with a save_path).")
			EditorInterface.play_current_scene()
		"main":
			var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
			if main_scene == "":
				return R.err("NO_MAIN_SCENE", "The project has no main scene. Use set_main_scene first.")
			EditorInterface.play_main_scene()
		"path":
			var path := String(params.get("path", ""))
			if not FileAccess.file_exists(path):
				return R.err("FILE_NOT_FOUND", "Scene '%s' does not exist." % path)
			EditorInterface.play_custom_scene(path)
	return R.ok({"playing": mode, "note": "Game started. Call wait_for_errors to collect runtime errors."})
