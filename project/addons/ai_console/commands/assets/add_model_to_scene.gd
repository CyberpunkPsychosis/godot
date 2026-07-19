@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "add_model_to_scene"
	description = "Instance an imported 3D model (.glb/.gltf/.fbx/.obj scene) into the edited scene and report the animations it ships with (from its AnimationPlayer). Use after download_asset/import_asset_zip. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"model_path": {"type": "string", "description": "e.g. res://assets/knight/knight.gltf"},
			"parent": {"type": "string", "default": "."},
			"name": {"type": "string"},
			"position": {"type": "array", "items": {"type": "number"}, "description": "[x, y, z] world offset."},
		},
		"required": ["model_path"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var model_path := String(params["model_path"])
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		return R.err("NOT_IMPORTED",
			"'%s' is not loadable as a scene yet. If it was just added, the import may still be running — call rescan_filesystem, wait a moment and retry. Supported: glb/gltf/fbx/obj/dae." % model_path)
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var instance := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if instance == null:
		return R.err("INSTANCE_FAILED", "Could not instantiate '%s'." % model_path)
	if params.has("name"):
		instance.name = String(params["name"])
	if params.has("position") and instance is Node3D:
		var pos: Array = params["position"]
		if pos.size() >= 3:
			(instance as Node3D).position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	parent.add_child(instance, true)
	ctx.ops.set_owner_recursive(instance, ctx.scene_root())
	ctx.begin_action("AI: add_model_to_scene")
	ctx.record_node_added(parent, instance)
	ctx.end_action()
	var animations := []
	var player := _find_animation_player(instance)
	if player != null:
		for animation_name in player.get_animation_list():
			animations.append(String(animation_name))
	return R.ok({
		"node": ctx.summarize_node(instance),
		"model": model_path,
		"animations": animations,
		"animation_player": ctx.node_path(player) if player != null else null,
	})


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
