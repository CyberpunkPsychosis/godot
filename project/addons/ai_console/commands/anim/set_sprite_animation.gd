@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "set_sprite_animation"
	description = "Set which animation an AnimatedSprite2D shows by default (the one selected in the editor, e.g. 'idle'). Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"animation": {"type": "string"},
		},
		"required": ["path", "animation"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var sprite := resolved["node"] as AnimatedSprite2D
	if sprite == null:
		return R.err("NOT_A_SPRITE", "Node is not an AnimatedSprite2D.")
	var animation_name := String(params["animation"])
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		var names := sprite.sprite_frames.get_animation_names() if sprite.sprite_frames != null else PackedStringArray()
		return R.err("ANIMATION_UNKNOWN", "No animation '%s'. Available: %s" % [animation_name, str(names)])
	var old_value := String(sprite.animation)
	ctx.ops.set_prop(sprite, "animation", animation_name)
	ctx.begin_action("AI: set_sprite_animation")
	ctx.record_property(sprite, "animation", old_value, animation_name)
	ctx.end_action()
	return R.ok({"node": ctx.summarize_node(sprite), "animation": animation_name})
