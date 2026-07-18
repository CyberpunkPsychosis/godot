@tool
extends "res://addons/ai_console/core/editor_command.gd"

const ClassUtil := preload("res://addons/ai_console/core/class_util.gd")


func _init() -> void:
	name = "get_class_info"
	description = "Introspect a Godot class: inheritance chain, key properties, signals and methods. This is your API documentation — use it before working with unfamiliar node types."
	params_schema = {
		"type": "object",
		"properties": {
			"class_name": {"type": "string", "description": "e.g. CharacterBody2D"},
		},
		"required": ["class_name"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var cls := String(params["class_name"])
	if not ClassDB.class_exists(cls):
		return R.err("CLASS_UNKNOWN",
			"Class '%s' does not exist. Similar: %s" % [cls, str(ClassUtil.suggest(cls))])
	var parents := []
	var walker := cls
	while walker != "":
		walker = ClassDB.get_parent_class(walker)
		if walker != "":
			parents.append(walker)
	var props := []
	for info in ClassDB.class_get_property_list(cls, true):
		if (info.usage & PROPERTY_USAGE_EDITOR) == 0 or info.type == TYPE_NIL:
			continue
		props.append({"name": String(info.name), "type": type_string(info.type)})
		if props.size() >= 60:
			break
	var signals := []
	for info in ClassDB.class_get_signal_list(cls, true):
		var args := []
		for arg in info.args:
			args.append(String(arg.name))
		signals.append({"name": String(info.name), "args": args})
		if signals.size() >= 40:
			break
	var methods := []
	for info in ClassDB.class_get_method_list(cls, true):
		methods.append(String(info.name))
		if methods.size() >= 80:
			break
	return R.ok({
		"class": cls,
		"inherits": parents,
		"can_instantiate": ClassDB.can_instantiate(cls),
		"own_properties": props,
		"own_signals": signals,
		"own_methods": methods,
		"note": "Lists show only members declared by this class; inherited members come from the classes in 'inherits'.",
	})
