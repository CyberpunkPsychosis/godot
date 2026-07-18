@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "set_property"
	description = "Set one property on a node. Values may be JSON primitives, arrays ([100, 50] becomes Vector2 for vector properties), Godot literals as strings (\"Vector2(3, 4)\", \"Color(1, 0, 0)\"), color names, or res:// resource paths (auto-loaded). Subproperties use colons, e.g. \"position:x\". Undoable. Use list_properties to discover valid properties."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Node path relative to scene root."},
			"property": {"type": "string"},
			"value": {"description": "New value (any JSON type)."},
		},
		"required": ["path", "property"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var prop := String(params["property"])
	if not Codec.has_property(node, prop):
		return R.err("PROPERTY_UNKNOWN",
			"Node '%s' (%s) has no property '%s'. Use list_properties to see valid properties." % [node.name, node.get_class(), prop])
	var old_value: Variant
	if prop.contains(":"):
		old_value = node.get_indexed(NodePath(prop))
	else:
		old_value = node.get(prop)
	var decoded: Dictionary = Codec.decode(params.get("value"), node, prop)
	if not decoded["ok"]:
		return R.err("VALUE_INVALID", String(decoded["message"]))
	ctx.ops.set_prop(node, prop, decoded["value"])
	ctx.begin_action("AI: set_property %s" % prop)
	ctx.record_property(node, prop, old_value, decoded["value"])
	ctx.end_action()
	var new_value: Variant
	if prop.contains(":"):
		new_value = node.get_indexed(NodePath(prop))
	else:
		new_value = node.get(prop)
	return R.ok({
		"node": ctx.summarize_node(node),
		"property": prop,
		"old_value": Codec.encode(old_value),
		"new_value": Codec.encode(new_value),
	})
