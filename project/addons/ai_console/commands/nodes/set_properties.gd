@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "set_properties"
	description = "Set multiple properties on a node in one undoable step. Same value coercion rules as set_property. Returns per-property errors without aborting the rest."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"properties": {"type": "object", "description": "Map of property name to new value."},
		},
		"required": ["path", "properties"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var props: Dictionary = params["properties"]
	var applied := {}
	var errors := []
	ctx.begin_action("AI: set_properties")
	for prop_key in props:
		var prop := String(prop_key)
		if not Codec.has_property(node, prop):
			errors.append("Unknown property '%s'" % prop)
			continue
		var decoded: Dictionary = Codec.decode(props[prop_key], node, prop)
		if not decoded["ok"]:
			errors.append("%s: %s" % [prop, decoded["message"]])
			continue
		var old_value: Variant = node.get_indexed(NodePath(prop)) if prop.contains(":") else node.get(prop)
		ctx.ops.set_prop(node, prop, decoded["value"])
		ctx.record_property(node, prop, old_value, decoded["value"])
		applied[prop] = Codec.encode(decoded["value"])
	ctx.end_action()
	var result := {"node": ctx.summarize_node(node), "applied": applied}
	if not errors.is_empty():
		result["errors"] = errors
	return R.ok(result)
