@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "get_scene_tree"
	description = "Return the node tree of the currently edited scene: names, types, attached scripts, groups and scene instances. Call this before modifying a scene you have not inspected yet. Output is truncated at max_nodes/max_depth with explicit markers."
	params_schema = {
		"type": "object",
		"properties": {
			"max_depth": {"type": "integer", "default": 8, "description": "Maximum tree depth to descend."},
			"max_nodes": {"type": "integer", "default": 500, "description": "Maximum total nodes to include."},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var root: Node = ctx.scene_root()
	if root == null:
		return R.err("NO_OPEN_SCENE", "No scene is open. Use new_scene or open_scene first.")
	var budget := {"nodes": int(params["max_nodes"])}
	var tree := _dump(root, int(params["max_depth"]), budget)
	return R.ok({
		"scene_path": root.scene_file_path,
		"tree": tree,
		"truncated": budget["nodes"] <= 0,
	})


func _dump(node: Node, depth: int, budget: Dictionary) -> Dictionary:
	budget["nodes"] -= 1
	var info := {"name": String(node.name), "type": node.get_class()}
	var script: Script = node.get_script()
	if script != null and script.resource_path != "":
		info["script"] = script.resource_path
	if node.scene_file_path != "":
		info["instance_of"] = node.scene_file_path
	var groups := []
	for group in node.get_groups():
		if not String(group).begins_with("_"):
			groups.append(String(group))
	if not groups.is_empty():
		info["groups"] = groups
	if node.get_child_count() > 0:
		if depth <= 0 or budget["nodes"] <= 0:
			info["children_omitted"] = node.get_child_count()
		else:
			var children := []
			for child in node.get_children():
				if budget["nodes"] <= 0:
					info["children_omitted"] = node.get_child_count() - children.size()
					break
				children.append(_dump(child, depth - 1, budget))
			info["children"] = children
	return info
