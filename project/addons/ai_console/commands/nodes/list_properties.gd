@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "list_properties"
	description = "List the editor-settable properties of a node (by path) or of any class (by class name), with types and hints. Use this to discover what set_property can change."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Node path in the edited scene."},
			"class_name": {"type": "string", "description": "Alternatively, a class name like Sprite2D."},
		},
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var property_list: Array = []
	var subject := ""
	if params.has("path"):
		var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
		if not resolved.get("ok", false):
			return resolved
		var node: Node = resolved["node"]
		property_list = node.get_property_list()
		subject = "%s (%s)" % [node.name, node.get_class()]
	elif params.has("class_name"):
		var cls := String(params["class_name"])
		if not ClassDB.class_exists(cls):
			return R.err("CLASS_UNKNOWN", "Class '%s' does not exist. Use search_classes." % cls)
		property_list = ClassDB.class_get_property_list(cls)
		subject = cls
	else:
		return R.err("SCHEMA_INVALID", "Pass either 'path' or 'class_name'.")
	var props := []
	for info in property_list:
		if (info.usage & PROPERTY_USAGE_EDITOR) == 0 or info.type == TYPE_NIL:
			continue
		var entry := {"name": String(info.name), "type": type_string(info.type)}
		if String(info.hint_string) != "":
			entry["hint"] = String(info.hint_string)
		props.append(entry)
		if props.size() >= 120:
			break
	return R.ok({"subject": subject, "properties": props})
