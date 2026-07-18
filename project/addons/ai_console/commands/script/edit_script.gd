@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "edit_script"
	description = "Modify an existing GDScript file: either replace the whole source (pass source) or do a targeted find/replace (pass find + replace; find must occur exactly once). The result is parse-checked and rejected if broken (force=true to override). Nodes using the script pick up the change immediately."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"source": {"type": "string", "description": "New complete source (full replace)."},
			"find": {"type": "string", "description": "Exact text to find (must match exactly once)."},
			"replace": {"type": "string", "description": "Replacement text for find."},
			"force": {"type": "boolean", "default": false},
		},
		"required": ["path"],
	}
	undoable = false
	destructive = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path: String = params["path"]
	if not FileAccess.file_exists(path):
		return R.err("FILE_NOT_FOUND", "Script '%s' does not exist. Use create_script for new files." % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return R.err("READ_FAILED", "Could not read '%s'." % path)
	var current := file.get_as_text()
	file.close()
	var next_source := ""
	if params.has("source"):
		next_source = String(params["source"])
	elif params.has("find") and params.has("replace"):
		var find := String(params["find"])
		var occurrences := current.count(find)
		if occurrences == 0:
			return R.err("FIND_NOT_FOUND",
				"The 'find' text does not occur in %s. Read the file with read_file and retry with exact text." % path)
		if occurrences > 1:
			return R.err("FIND_AMBIGUOUS",
				"The 'find' text occurs %d times in %s; it must be unique. Include more surrounding context." % [occurrences, path])
		next_source = current.replace(find, String(params["replace"]))
	else:
		return R.err("SCHEMA_INVALID", "Pass either 'source' (full replace) or both 'find' and 'replace'.")
	if not params["force"]:
		var probe := GDScript.new()
		probe.source_code = next_source
		var parse_err := probe.reload()
		if parse_err != OK:
			return R.err("SCRIPT_PARSE_ERROR",
				"The edited script fails to parse/compile (error %d); the file was NOT changed. Fix the edit or pass force=true." % parse_err)
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return R.err("WRITE_FAILED", "Could not write '%s'." % path)
	out.store_string(next_source)
	out.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	var loaded := load(path) as GDScript
	if loaded != null:
		loaded.source_code = next_source
		loaded.reload(true)
	return R.ok({"path": path, "lines": next_source.split("\n").size()})
