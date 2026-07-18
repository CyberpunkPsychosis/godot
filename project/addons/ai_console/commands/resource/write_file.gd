@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "write_file"
	description = "Write a text file into the project (res:// only; directories are created as needed). For .gd files prefer create_script/edit_script, which parse-check the code. Overwriting an existing file requires approval."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"content": {"type": "string"},
		},
		"required": ["path", "content"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("path", "")))


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path := String(params["path"])
	if not path.begins_with("res://") or path.contains(".."):
		return R.err("INVALID_PATH", "path must be inside res:// with no '..' segments.")
	if path.begins_with("res://.godot"):
		return R.err("INVALID_PATH", "Writing into res://.godot (editor internals) is not allowed.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return R.err("WRITE_FAILED", "Could not open '%s' for writing (error %d)." % [path, FileAccess.get_open_error()])
	file.store_string(String(params["content"]))
	file.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return R.ok({"path": path})
