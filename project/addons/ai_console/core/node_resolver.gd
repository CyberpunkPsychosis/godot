@tool
extends RefCounted
## Resolves node paths sent by AIs into live nodes of the edited scene.
## Convention: paths are relative to the scene root; "." (or "") is the root
## itself; "%Name" resolves scene-unique names. On failure the error lists the
## children of the deepest resolvable ancestor so the LLM can self-correct.

const R := preload("res://addons/ai_console/core/command_result.gd")


static func resolve(root: Node, raw_path: String) -> Dictionary:
	if raw_path.is_empty() or raw_path == "." or raw_path == "/":
		return {"ok": true, "node": root}
	if raw_path.begins_with("%"):
		var unique := root.get_node_or_null(raw_path)
		if unique != null:
			return {"ok": true, "node": unique}
		return R.err("NODE_NOT_FOUND",
			"No node with scene-unique name '%s'. Use get_scene_tree to inspect the scene." % raw_path)
	var path := raw_path.trim_prefix("./")
	if path.begins_with("/"):
		return R.err("INVALID_PATH",
			"Node paths must be relative to the scene root (use '.' for the root itself); got absolute path '%s'." % raw_path)
	if path == String(root.name):
		return {"ok": true, "node": root}
	if path.begins_with(String(root.name) + "/"):
		path = path.substr(String(root.name).length() + 1)
	var node := root.get_node_or_null(path)
	if node != null:
		return {"ok": true, "node": node}
	# Walk segment by segment to produce a helpful error.
	var current := root
	var resolved: Array[String] = []
	for segment in path.split("/"):
		var next := current.get_node_or_null(NodePath(segment))
		if next == null:
			var child_names: Array[String] = []
			for child in current.get_children():
				child_names.append(String(child.name))
			var where: String = ("scene root '%s'" % root.name) if resolved.is_empty() else ("'%s'" % "/".join(resolved))
			return R.err("NODE_NOT_FOUND",
				"Node '%s' not found under %s. Available children: %s" % [segment, where, str(child_names)])
		current = next
		resolved.append(segment)
	return {"ok": true, "node": current}


static func path_of(node: Node, root: Node) -> String:
	if node == root:
		return "."
	return String(root.get_path_to(node))
