@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "add_to_group"
	description = "Add a node to a group (persistent, saved with the scene) or remove it with remove=true. Groups are how Godot tags nodes for lookup (e.g. \"enemies\"). Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"group": {"type": "string"},
			"remove": {"type": "boolean", "default": false},
		},
		"required": ["path", "group"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var group := String(params["group"])
	var removing: bool = params["remove"]
	var ur: EditorUndoRedoManager = ctx.undo_redo()
	if removing:
		if not node.is_in_group(group):
			return R.err("NOT_IN_GROUP", "Node '%s' is not in group '%s'." % [node.name, group])
		ctx.ops.remove_group(node, group)
		ctx.begin_action("AI: remove_from_group")
		ur.add_do_method(ctx.ops, "remove_group", node, group)
		ur.add_undo_method(ctx.ops, "add_group", node, group)
		ctx.end_action()
	else:
		ctx.ops.add_group(node, group)
		ctx.begin_action("AI: add_to_group")
		ur.add_do_method(ctx.ops, "add_group", node, group)
		ur.add_undo_method(ctx.ops, "remove_group", node, group)
		ctx.end_action()
	var groups := []
	for g in node.get_groups():
		if not String(g).begins_with("_"):
			groups.append(String(g))
	return R.ok({"node": ctx.summarize_node(node), "groups": groups})
