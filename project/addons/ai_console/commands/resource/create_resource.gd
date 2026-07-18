@tool
extends "res://addons/ai_console/core/editor_command.gd"

const ClassUtil := preload("res://addons/ai_console/core/class_util.gd")
const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "create_resource"
	description = "Create and save a Resource of any class (.tres), e.g. RectangleShape2D, CapsuleShape2D, Theme, LabelSettings, with initial properties. The saved resource can then be referenced by res:// path in set_property."
	params_schema = {
		"type": "object",
		"properties": {
			"type": {"type": "string", "description": "Resource class, e.g. RectangleShape2D."},
			"path": {"type": "string", "description": "Save path like res://resources/box_shape.tres"},
			"properties": {"type": "object", "description": "Optional initial properties, e.g. {\"size\": [64, 32]}."},
		},
		"required": ["type", "path"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("path", "")))


func execute(params: Dictionary, _ctx) -> Dictionary:
	var type := String(params["type"])
	var check := ClassUtil.check_instantiable(type, "Resource")
	if not check.is_empty():
		return check
	var path := String(params["path"])
	if not path.begins_with("res://") or not (path.ends_with(".tres") or path.ends_with(".res")):
		return R.err("INVALID_PATH", "path must be a res:// path ending in .tres or .res")
	var resource: Resource = ClassDB.instantiate(type)
	var errors := []
	var props: Dictionary = params.get("properties", {})
	for prop in props:
		if not Codec.has_property(resource, String(prop)):
			errors.append("Unknown property '%s' on %s" % [prop, type])
			continue
		var decoded: Dictionary = Codec.decode(props[prop], resource, String(prop))
		if decoded["ok"]:
			resource.set(String(prop), decoded["value"])
		else:
			errors.append("%s: %s" % [prop, decoded["message"]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_err := ResourceSaver.save(resource, path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save resource to '%s' (error %d)." % [path, save_err])
	EditorInterface.get_resource_filesystem().update_file(path)
	var result := {"path": path, "type": type}
	if not errors.is_empty():
		result["property_errors"] = errors
	return R.ok(result)
