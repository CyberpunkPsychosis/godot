@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "play_animation"
	description = "Preview an animation inside the editor on an AnimationPlayer or AnimatedSprite2D (also pass stop=true to stop). Lets the user see a downloaded character's walk/attack before wiring gameplay."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"animation": {"type": "string"},
			"stop": {"type": "boolean", "default": false},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var animation_name := String(params.get("animation", ""))
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		if params["stop"]:
			player.stop()
			return R.ok({"stopped": true})
		if not player.has_animation(animation_name):
			return R.err("ANIMATION_UNKNOWN",
				"No animation '%s'. Available: %s" % [animation_name, str(player.get_animation_list())])
		player.play(animation_name)
		return R.ok({"playing": animation_name})
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if params["stop"]:
			sprite.stop()
			return R.ok({"stopped": true})
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
			var names := sprite.sprite_frames.get_animation_names() if sprite.sprite_frames != null else PackedStringArray()
			return R.err("ANIMATION_UNKNOWN", "No animation '%s'. Available: %s" % [animation_name, str(names)])
		sprite.play(animation_name)
		return R.ok({"playing": animation_name})
	return R.err("NOT_ANIMATABLE", "Node '%s' (%s) cannot play animations." % [node.name, node.get_class()])
