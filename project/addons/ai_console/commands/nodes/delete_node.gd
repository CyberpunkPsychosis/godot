@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "delete_node"
	description = "Remove a node (and all its children) from the edited scene. Undoable with Ctrl+Z. Deleting a node that has children requires user approval."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Node path relative to the scene root."},
		},
		"required": ["path"],
	}


func is_destructive(params: Dictionary, ctx) -> bool:
	if ctx == null:
		return true
	var resolved: Dictionary = ctx.resolve_node(String(params.get("path", "")))
	if not resolved.get("ok", false):
		return false  # Will fail in execute with a proper error anyway.
	var node: Node = resolved["node"]
	return node.get_child_count() > 0


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	if node == ctx.scene_root():
		return R.err("CANNOT_DELETE_ROOT",
			"Cannot delete the scene root. Open or create a different scene instead.")
	var parent := node.get_parent()
	var index := node.get_index()
	var summary: Dictionary = ctx.summarize_node(node)
	ctx.ops.detach(node)
	ctx.begin_action("AI: delete_node %s" % summary["name"])
	ctx.record_node_removed(parent, node, index)
	ctx.end_action()
	return R.ok({"deleted": summary})
