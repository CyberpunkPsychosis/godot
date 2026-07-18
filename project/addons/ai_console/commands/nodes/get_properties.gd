@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "get_properties"
	description = "Read property values from a node. Pass specific property names, or omit to get all editor-visible properties (capped at 80)."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"properties": {"type": "array", "items": {"type": "string"}, "description": "Optional list of property names."},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var values := {}
	if params.has("properties"):
		for prop_key in params["properties"]:
			var prop := String(prop_key)
			if Codec.has_property(node, prop):
				var value: Variant = node.get_indexed(NodePath(prop)) if prop.contains(":") else node.get(prop)
				values[prop] = Codec.encode(value)
			else:
				values[prop] = "<unknown property>"
	else:
		var count := 0
		for info in node.get_property_list():
			if count >= 80:
				break
			if (info.usage & PROPERTY_USAGE_EDITOR) == 0 or info.type == TYPE_NIL:
				continue
			values[String(info.name)] = Codec.encode(node.get(info.name))
			count += 1
	return R.ok({"node": ctx.summarize_node(node), "values": values})
