@tool
extends "res://addons/ai_console/core/editor_command.gd"

const ClassUtil := preload("res://addons/ai_console/core/class_util.gd")


func _init() -> void:
	name = "new_scene"
	description = "Create a new scene file with a root node of the given class, save it to save_path (.tscn under res://) and open it for editing. Overwriting an existing scene file requires approval."
	params_schema = {
		"type": "object",
		"properties": {
			"root_type": {"type": "string", "default": "Node2D", "description": "Class of the root node, e.g. Node2D, Node3D, Control."},
			"root_name": {"type": "string", "default": "Main"},
			"save_path": {"type": "string", "description": "Target path like res://scenes/main.tscn"},
		},
		"required": ["save_path"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("save_path", "")))


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path: String = params["save_path"]
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return R.err("INVALID_PATH", "save_path must be a res:// path ending in .tscn, got '%s'." % path)
	var type: String = params["root_type"]
	var check := ClassUtil.check_instantiable(type, "Node")
	if not check.is_empty():
		return check
	var node: Node = ClassDB.instantiate(type)
	node.name = String(params["root_name"])
	var packed := PackedScene.new()
	packed.pack(node)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_err := ResourceSaver.save(packed, path)
	node.free()
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save scene to '%s' (error %d)." % [path, save_err])
	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	return R.ok({"scene_path": path, "root_type": type, "root_name": String(params["root_name"])})
