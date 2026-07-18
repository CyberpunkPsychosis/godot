@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "save_scene"
	description = "Save the currently edited scene. If save_path is given, saves a copy there (save-as); otherwise saves in place. Always save after finishing a set of scene edits."
	params_schema = {
		"type": "object",
		"properties": {
			"save_path": {"type": "string", "description": "Optional res://... .tscn path for save-as."},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var root: Node = ctx.scene_root()
	if root == null:
		return R.err("NO_OPEN_SCENE", "No scene is open to save.")
	var path: String = String(params.get("save_path", ""))
	if path == "":
		if root.scene_file_path == "":
			return R.err("NO_SAVE_PATH",
				"This scene has never been saved. Pass save_path (e.g. res://scenes/main.tscn).")
		var err := EditorInterface.save_scene()
		if err != OK:
			return R.err("SAVE_FAILED", "save_scene failed with error %d." % err)
		return R.ok({"scene_path": root.scene_file_path})
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return R.err("INVALID_PATH", "save_path must be a res:// path ending in .tscn.")
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return R.err("PACK_FAILED", "Could not pack the scene (error %d)." % pack_err)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save to '%s' (error %d)." % [path, save_err])
	EditorInterface.get_resource_filesystem().update_file(path)
	return R.ok({"scene_path": path})
