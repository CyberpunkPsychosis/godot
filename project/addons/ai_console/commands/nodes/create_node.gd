@tool
extends "res://addons/ai_console/core/editor_command.gd"

const ClassUtil := preload("res://addons/ai_console/core/class_util.gd")
const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "create_node"
	description = "Create a node of the given class and add it to the edited scene (like clicking + in the Scene dock). Optionally set initial properties, e.g. {\"position\": [100, 50]}. Undoable with Ctrl+Z. Use get_class_info to discover valid classes and properties."
	params_schema = {
		"type": "object",
		"properties": {
			"type": {"type": "string", "description": "Node class, e.g. Sprite2D, CharacterBody2D, Label."},
			"parent": {"type": "string", "default": ".", "description": "Parent node path relative to the scene root ('.' = root)."},
			"name": {"type": "string", "description": "Optional node name (defaults to the class name)."},
			"properties": {"type": "object", "description": "Optional initial properties, e.g. {\"position\": [100, 50], \"texture\": \"res://icon.svg\"}."},
		},
		"required": ["type"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var type: String = params["type"]
	var check := ClassUtil.check_instantiable(type, "Node")
	if not check.is_empty():
		return check
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var node: Node = ClassDB.instantiate(type)
	if params.has("name"):
		node.name = String(params["name"])
	var property_errors := []
	var props: Dictionary = params.get("properties", {})
	for prop in props:
		if not Codec.has_property(node, String(prop)):
			property_errors.append("Unknown property '%s' on %s" % [prop, type])
			continue
		var decoded: Dictionary = Codec.decode(props[prop], node, String(prop))
		if decoded["ok"]:
			node.set(String(prop), decoded["value"])
		else:
			property_errors.append("%s: %s" % [prop, decoded["message"]])
	parent.add_child(node, true)
	ctx.ops.set_owner_recursive(node, ctx.scene_root())
	ctx.begin_action("AI: create_node %s" % node.name)
	ctx.record_node_added(parent, node)
	ctx.end_action()
	var result := {"node": ctx.summarize_node(node)}
	if not property_errors.is_empty():
		result["property_errors"] = property_errors
	return R.ok(result)
