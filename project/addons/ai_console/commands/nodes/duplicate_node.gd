@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "duplicate_node"
	description = "Duplicate a node with its children, scripts, groups and signal connections, inserting the copy as the next sibling. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"new_name": {"type": "string", "description": "Optional name for the copy."},
		},
		"required": ["path"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	if node == ctx.scene_root():
		return R.err("CANNOT_DUPLICATE_ROOT", "Cannot duplicate the scene root.")
	var copy := node.duplicate()
	if params.has("new_name"):
		copy.name = String(params["new_name"])
	var parent := node.get_parent()
	parent.add_child(copy, true)
	parent.move_child(copy, node.get_index() + 1)
	ctx.ops.set_owner_recursive(copy, ctx.scene_root())
	ctx.begin_action("AI: duplicate_node")
	ctx.record_node_added(parent, copy)
	ctx.end_action()
	return R.ok({"node": ctx.summarize_node(copy)})
