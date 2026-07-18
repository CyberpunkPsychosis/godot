@tool
extends "res://addons/ai_console/core/editor_command.gd"

const NodeResolver := preload("res://addons/ai_console/core/node_resolver.gd")


func _init() -> void:
	name = "get_selection"
	description = "Return the nodes currently selected in the Scene dock — useful when the user says \"this node\" or \"the selected sprite\"."
	params_schema = {"type": "object", "properties": {}}
	undoable = false


func execute(_params: Dictionary, ctx) -> Dictionary:
	var root: Node = ctx.scene_root()
	if root == null:
		return R.err("NO_OPEN_SCENE", "No scene is open.")
	var selection := []
	for node in EditorInterface.get_selection().get_selected_nodes():
		selection.append({
			"path": NodeResolver.path_of(node, root),
			"type": node.get_class(),
		})
	return R.ok({"selected": selection})
