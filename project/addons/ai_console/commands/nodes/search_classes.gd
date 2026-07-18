@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "search_classes"
	description = "Search Godot's class registry by substring, optionally filtered to descendants of a base class (e.g. base=\"Node2D\"). Use when unsure of an exact class name."
	params_schema = {
		"type": "object",
		"properties": {
			"query": {"type": "string"},
			"base": {"type": "string", "description": "Optional base class filter, e.g. Node, Control, Resource."},
			"limit": {"type": "integer", "default": 30},
		},
		"required": ["query"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var query := String(params["query"]).to_lower()
	var base := String(params.get("base", ""))
	if base != "" and not ClassDB.class_exists(base):
		return R.err("CLASS_UNKNOWN", "Base class '%s' does not exist." % base)
	var limit: int = int(params["limit"])
	var matches := []
	for cls in ClassDB.get_class_list():
		var cls_name := String(cls)
		if not cls_name.to_lower().contains(query):
			continue
		if base != "" and not ClassDB.is_parent_class(cls_name, base):
			continue
		matches.append({"class": cls_name, "instantiable": ClassDB.can_instantiate(cls_name)})
		if matches.size() >= limit:
			break
	return R.ok({"matches": matches})
