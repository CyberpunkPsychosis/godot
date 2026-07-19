@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "create_sprite_frames"
	description = "Slice a spritesheet texture into a SpriteFrames resource for AnimatedSprite2D — the standard way to animate 2D characters from Aseprite/Kenney sheets. Give the grid (hframes x vframes) and named animations with frame indices (left-to-right, top-to-bottom, starting at 0), e.g. animations=[{\"name\":\"idle\",\"frames\":[0,1],\"fps\":4},{\"name\":\"run\",\"frames\":[8,9,10,11],\"fps\":10}]. Optionally attach to an existing AnimatedSprite2D node."
	params_schema = {
		"type": "object",
		"properties": {
			"texture": {"type": "string", "description": "Spritesheet path, e.g. res://assets/hero/sheet.png"},
			"hframes": {"type": "integer", "description": "Columns in the sheet."},
			"vframes": {"type": "integer", "description": "Rows in the sheet."},
			"animations": {"type": "array", "items": {"type": "object"}, "description": "[{name, frames:[int], fps, loop}]"},
			"save_path": {"type": "string", "description": "Defaults to <texture_dir>/<texture_name>_frames.tres"},
			"attach_to": {"type": "string", "description": "Optional AnimatedSprite2D node path to receive the frames."},
		},
		"required": ["texture", "hframes", "vframes", "animations"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("save_path", "")))


func execute(params: Dictionary, ctx) -> Dictionary:
	var texture_path := String(params["texture"])
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return R.err("FILE_NOT_FOUND",
			"'%s' is not a loadable texture (if just added, run rescan_filesystem and retry)." % texture_path)
	var hframes := int(params["hframes"])
	var vframes := int(params["vframes"])
	if hframes < 1 or vframes < 1:
		return R.err("SCHEMA_INVALID", "hframes and vframes must be >= 1.")
	var frame_width := int(texture.get_width() / float(hframes))
	var frame_height := int(texture.get_height() / float(vframes))
	var total := hframes * vframes
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var built := []
	for animation in params["animations"]:
		var animation_name := String(animation.get("name", ""))
		if animation_name == "":
			return R.err("SCHEMA_INVALID", "Every animation needs a 'name'.")
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(animation.get("fps", 8)))
		frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		for frame_index in animation.get("frames", []):
			var index := int(frame_index)
			if index < 0 or index >= total:
				return R.err("FRAME_OUT_OF_RANGE",
					"Frame %d is outside the sheet (0-%d for a %dx%d grid)." % [index, total - 1, hframes, vframes])
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			@warning_ignore("integer_division")
			atlas.region = Rect2(
				(index % hframes) * frame_width,
				(index / hframes) * frame_height,
				frame_width, frame_height)
			frames.add_frame(animation_name, atlas)
		built.append(animation_name)
	var save_path := String(params.get("save_path", ""))
	if save_path == "":
		save_path = texture_path.get_base_dir().path_join(texture_path.get_file().get_basename() + "_frames.tres")
	var save_err := ResourceSaver.save(frames, save_path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save SpriteFrames (error %d)." % save_err)
	EditorInterface.get_resource_filesystem().update_file(save_path)
	var result := {
		"sprite_frames": save_path,
		"animations": built,
		"frame_size": [frame_width, frame_height],
	}
	if params.has("attach_to"):
		var resolved: Dictionary = ctx.resolve_node(String(params["attach_to"]))
		if not resolved.get("ok", false):
			result["attach_error"] = resolved["error"]
			return R.ok(result)
		var node: Node = resolved["node"]
		var sprite := node as AnimatedSprite2D
		if sprite == null:
			result["attach_error"] = "Node '%s' is %s, not AnimatedSprite2D." % [node.name, node.get_class()]
			return R.ok(result)
		var old_frames: Variant = sprite.sprite_frames
		var saved_frames := load(save_path)
		ctx.ops.set_prop(sprite, "sprite_frames", saved_frames)
		if not built.is_empty():
			sprite.animation = StringName(built[0])
		ctx.begin_action("AI: attach sprite_frames")
		ctx.record_property(sprite, "sprite_frames", old_frames, saved_frames)
		ctx.end_action()
		result["attached_to"] = ctx.summarize_node(node)
	return R.ok(result)
