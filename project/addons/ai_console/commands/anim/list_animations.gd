@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "list_animations"
	description = "List the animations available on an AnimationPlayer or AnimatedSprite2D node (names, lengths, loop). Use before play_animation or wiring animations into a character script."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var animations := []
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for animation_name in player.get_animation_list():
			var animation := player.get_animation(animation_name)
			animations.append({
				"name": String(animation_name),
				"length": animation.length,
				"loop": animation.loop_mode != Animation.LOOP_NONE,
			})
	elif node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.sprite_frames != null:
			for animation_name in sprite.sprite_frames.get_animation_names():
				animations.append({
					"name": String(animation_name),
					"fps": sprite.sprite_frames.get_animation_speed(animation_name),
					"frames": sprite.sprite_frames.get_frame_count(animation_name),
					"loop": sprite.sprite_frames.get_animation_loop(animation_name),
				})
	else:
		return R.err("NOT_ANIMATABLE",
			"Node '%s' (%s) is neither AnimationPlayer nor AnimatedSprite2D. Use get_scene_tree to find one (imported glb models usually contain an AnimationPlayer)." % [node.name, node.get_class()])
	return R.ok({"node": ctx.summarize_node(node), "animations": animations})
