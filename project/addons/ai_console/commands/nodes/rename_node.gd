@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "rename_node"
	description = "Rename a node in the edited scene. Node paths used afterwards must use the new name. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"new_name": {"type": "string"},
		},
		"required": ["path", "new_name"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var old_name := String(node.name)
	node.name = String(params["new_name"])
	ctx.begin_action("AI: rename_node")
	ctx.record_property(node, "name", old_name, String(node.name))
	ctx.end_action()
	return R.ok({"old_name": old_name, "node": ctx.summarize_node(node)})
