@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "select_nodes"
	description = "Select nodes in the Scene dock and show the first one in the Inspector, so the user can see what you are referring to."
	params_schema = {
		"type": "object",
		"properties": {
			"paths": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["paths"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var selection := EditorInterface.get_selection()
	selection.clear()
	var selected := []
	var errors := []
	for path in params["paths"]:
		var resolved: Dictionary = ctx.resolve_node(String(path))
		if resolved.get("ok", false):
			var node: Node = resolved["node"]
			selection.add_node(node)
			selected.append(ctx.summarize_node(node))
		else:
			errors.append(resolved["error"]["message"])
	if not selected.is_empty():
		var first: Dictionary = ctx.resolve_node(String(selected[0]["path"]))
		if first.get("ok", false):
			EditorInterface.edit_node(first["node"])
	var result := {"selected": selected}
	if not errors.is_empty():
		result["errors"] = errors
	return R.ok(result)
