@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "attach_script"
	description = "Attach an existing script file to a node, or detach the current script by passing an empty script_path. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Node path."},
			"script_path": {"type": "string", "default": "", "description": "Script res:// path, or \"\" to detach."},
		},
		"required": ["path"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var script_path := String(params["script_path"])
	var old_script: Variant = node.get_script()
	var new_script: Variant = null
	if script_path != "":
		if not FileAccess.file_exists(script_path):
			return R.err("FILE_NOT_FOUND", "Script '%s' does not exist. Create it with create_script." % script_path)
		new_script = load(script_path)
		if new_script == null:
			return R.err("LOAD_FAILED", "Could not load script '%s' (check the Output panel for parse errors)." % script_path)
	node.set_script(new_script)
	ctx.begin_action("AI: attach_script")
	ctx.record_property(node, "script", old_script, new_script)
	ctx.end_action()
	return R.ok({"node": ctx.summarize_node(node), "script": script_path})
