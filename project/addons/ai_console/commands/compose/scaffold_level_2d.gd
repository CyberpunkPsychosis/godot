@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "scaffold_level_2d"
	description = "Block out a simple 2D platformer level in the current scene: a static ground platform with collision, a visible floor rectangle, a SpawnPoint marker, and optionally an instanced player scene placed at the spawn. One Ctrl+Z undoes it all."
	params_schema = {
		"type": "object",
		"properties": {
			"parent": {"type": "string", "default": "."},
			"ground_width": {"type": "integer", "default": 2000},
			"player_scene": {"type": "string", "description": "Optional res://... .tscn to instance at the spawn point."},
			"save": {"type": "boolean", "default": true},
		},
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var root: Node = ctx.scene_root()
	var notes := []
	var width := float(int(params["ground_width"]))

	var level := Node2D.new()
	level.name = "LevelGeometry"

	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(0, 500)
	var ground_shape := CollisionShape2D.new()
	ground_shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 100)
	ground_shape.shape = rect
	ground.add_child(ground_shape)
	var ground_visual := ColorRect.new()
	ground_visual.name = "Visual"
	ground_visual.color = Color(0.35, 0.25, 0.15)
	ground_visual.position = Vector2(-width * 0.5, -50)
	ground_visual.size = Vector2(width, 100)
	ground.add_child(ground_visual)
	level.add_child(ground)

	var spawn := Marker2D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector2(0, 380)
	level.add_child(spawn)

	parent.add_child(level, true)
	ctx.ops.set_owner_recursive(level, root)
	ctx.begin_action("AI: scaffold_level_2d")
	ctx.record_node_added(parent, level)

	var player_scene := String(params.get("player_scene", ""))
	if player_scene != "":
		var packed: PackedScene = load(player_scene) as PackedScene
		if packed == null:
			notes.append("player_scene '%s' could not be loaded; skipped." % player_scene)
		else:
			var player := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			player.position = spawn.position
			parent.add_child(player, true)
			ctx.ops.set_owner_recursive(player, root)
			ctx.record_node_added(parent, player)
	ctx.end_action()

	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)

	return R.ok({
		"level": ctx.summarize_node(level),
		"spawn_point": "LevelGeometry/SpawnPoint",
		"notes": notes,
	})
