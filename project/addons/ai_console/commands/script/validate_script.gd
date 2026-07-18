@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "validate_script"
	description = "Parse-check GDScript source (pass source directly, or path to check an existing file) WITHOUT saving anything. Use before create_script/edit_script when unsure about syntax."
	params_schema = {
		"type": "object",
		"properties": {
			"source": {"type": "string"},
			"path": {"type": "string"},
		},
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var source := ""
	if params.has("source"):
		source = String(params["source"])
	elif params.has("path"):
		var path := String(params["path"])
		if not FileAccess.file_exists(path):
			return R.err("FILE_NOT_FOUND", "'%s' does not exist." % path)
		var file := FileAccess.open(path, FileAccess.READ)
		source = file.get_as_text()
		file.close()
	else:
		return R.err("SCHEMA_INVALID", "Pass 'source' or 'path'.")
	var probe := GDScript.new()
	probe.source_code = source
	var parse_err := probe.reload()
	return R.ok({
		"valid": parse_err == OK,
		"error_code": parse_err,
		"note": "" if parse_err == OK else "Parse/compile failed; details are printed in the editor Output panel.",
	})
