@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "read_file"
	description = "Read a text file from the project (scripts, scenes, resources, config). Binary files are rejected. Output truncated at max_bytes with a marker."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"max_bytes": {"type": "integer", "default": 32768},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path := String(params["path"])
	if not path.begins_with("res://"):
		return R.err("INVALID_PATH", "path must start with res://")
	if not FileAccess.file_exists(path):
		return R.err("FILE_NOT_FOUND", "'%s' does not exist. Use list_files to browse." % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return R.err("READ_FAILED", "Could not open '%s' (error %d)." % [path, FileAccess.get_open_error()])
	var max_bytes := int(params["max_bytes"])
	var size := file.get_length()
	var raw := file.get_buffer(mini(size, max_bytes))
	file.close()
	if raw.find(0) != -1:
		return R.err("BINARY_FILE", "'%s' looks binary; only text files can be read." % path)
	return R.ok({
		"path": path,
		"content": raw.get_string_from_utf8(),
		"truncated": size > max_bytes,
		"total_bytes": size,
	})
