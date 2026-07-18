@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "move_node"
	description = "Reparent a node to a new parent and/or change its position among siblings (like dragging it in the Scene dock). keep_global_transform preserves the on-screen position of 2D/3D nodes. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"new_parent": {"type": "string", "default": ".", "description": "New parent path relative to scene root."},
			"index": {"type": "integer", "default": -1, "description": "Position among siblings, -1 = append last."},
			"keep_global_transform": {"type": "boolean", "default": true},
		},
		"required": ["path"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	if node == ctx.scene_root():
		return R.err("CANNOT_MOVE_ROOT", "Cannot reparent the scene root.")
	var parent_result: Dictionary = ctx.resolve_node(String(params["new_parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var new_parent: Node = parent_result["node"]
	if new_parent == node or node.is_ancestor_of(new_parent):
		return R.err("CYCLIC_MOVE", "Cannot move a node into itself or its own subtree.")
	var old_parent := node.get_parent()
	var old_index := node.get_index()
	var keep: bool = params["keep_global_transform"]
	var index: int = int(params["index"])
	var root: Node = ctx.scene_root()
	ctx.ops.reparent_node(node, new_parent, index, keep, root)
	ctx.begin_action("AI: move_node")
	var ur: EditorUndoRedoManager = ctx.undo_redo()
	ur.add_do_method(ctx.ops, "reparent_node", node, new_parent, index, keep, root)
	ur.add_undo_method(ctx.ops, "reparent_node", node, old_parent, old_index, keep, root)
	ctx.end_action()
	return R.ok({"node": ctx.summarize_node(node)})
