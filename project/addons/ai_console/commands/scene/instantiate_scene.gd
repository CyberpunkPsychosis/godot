@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "instantiate_scene"
	description = "Instance an existing .tscn scene as a child of a node in the currently edited scene (like dragging a scene from the FileSystem dock into the scene tree). Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Scene to instance, e.g. res://scenes/player.tscn"},
			"parent": {"type": "string", "default": ".", "description": "Parent node path relative to scene root."},
			"name": {"type": "string", "description": "Optional name for the instance."},
		},
		"required": ["path"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var path: String = params["path"]
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return R.err("FILE_NOT_FOUND", "'%s' is not a loadable scene. Use list_files to find scenes." % path)
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var root: Node = ctx.scene_root()
	if path == root.scene_file_path:
		return R.err("CYCLIC_INSTANCE", "Cannot instance a scene inside itself.")
	var instance := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if instance == null:
		return R.err("INSTANCE_FAILED", "Failed to instantiate '%s'." % path)
	if params.has("name"):
		instance.name = String(params["name"])
	parent.add_child(instance)
	ctx.ops.set_owner_recursive(instance, root)
	ctx.begin_action("AI: instantiate_scene")
	ctx.record_node_added(parent, instance)
	ctx.end_action()
	return R.ok({"instance": ctx.summarize_node(instance), "instance_of": path})
