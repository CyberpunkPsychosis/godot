@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "create_script"
	description = "Write a new GDScript file and optionally attach it to a node. The source is parse-checked first and rejected if broken (pass force=true to save anyway). Overwriting an existing file requires approval."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Target path like res://scripts/player.gd"},
			"source": {"type": "string", "description": "Complete GDScript source code."},
			"attach_to": {"type": "string", "description": "Optional node path to attach the script to."},
			"force": {"type": "boolean", "default": false, "description": "Save even if the script fails to parse."},
		},
		"required": ["path", "source"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("path", "")))


func execute(params: Dictionary, ctx) -> Dictionary:
	var path: String = params["path"]
	if not path.begins_with("res://") or not path.ends_with(".gd"):
		return R.err("INVALID_PATH", "path must be a res:// path ending in .gd, got '%s'." % path)
	var source: String = params["source"]
	if not params["force"]:
		var probe := GDScript.new()
		probe.source_code = source
		var parse_err := probe.reload()
		if parse_err != OK:
			return R.err("SCRIPT_PARSE_ERROR",
				"The script fails to parse/compile (error %d) and was NOT saved. Fix the source or pass force=true. Parse errors are printed in the editor Output panel." % parse_err)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return R.err("WRITE_FAILED", "Could not open '%s' for writing (error %d)." % [path, FileAccess.get_open_error()])
	file.store_string(source)
	file.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	var result := {"path": path, "lines": source.split("\n").size()}
	if params.has("attach_to"):
		var resolved: Dictionary = ctx.resolve_node(String(params["attach_to"]))
		if not resolved.get("ok", false):
			result["attach_error"] = resolved["error"]
			return R.ok(result)
		var node: Node = resolved["node"]
		var old_script: Variant = node.get_script()
		var new_script := load(path)
		node.set_script(new_script)
		ctx.begin_action("AI: attach_script")
		ctx.record_property(node, "script", old_script, new_script)
		ctx.end_action()
		result["attached_to"] = ctx.summarize_node(node)
	return R.ok(result)
