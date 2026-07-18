@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "list_files"
	description = "List project files under a res:// directory (recursive by default), optionally filtered by extensions like [\"gd\", \"tscn\"]. Skips .godot and hidden folders. Capped at 500 entries."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"recursive": {"type": "boolean", "default": true},
			"extensions": {"type": "array", "items": {"type": "string"}},
		},
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var base := String(params["path"])
	if not base.begins_with("res://"):
		return R.err("INVALID_PATH", "path must start with res://")
	var extensions: Array = params.get("extensions", [])
	var files: Array[String] = []
	_walk(base.trim_suffix("/"), bool(params["recursive"]), extensions, files)
	return R.ok({"files": files, "truncated": files.size() >= 500})


func _walk(path: String, recursive: bool, extensions: Array, out: Array[String]) -> void:
	if out.size() >= 500:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and out.size() < 500:
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if recursive and not entry.begins_with(".") and full != "res://addons/ai_console":
				_walk(full, recursive, extensions, out)
		elif not entry.ends_with(".import") and not entry.ends_with(".uid"):
			if extensions.is_empty() or (entry.get_extension() in extensions):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
