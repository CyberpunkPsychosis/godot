@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "build_character_2d"
	description = "Build a complete, playable 2D character in one step: CharacterBody2D + visual + collision + optional Camera2D, movement script and move_left/move_right/jump input actions. Visual options: pass sprite_frames (a SpriteFrames .tres from create_sprite_frames) for an ANIMATED character that auto-switches idle/run/jump, or sprite_texture for a static sprite, or nothing for a generated placeholder. One Ctrl+Z undoes the whole character. Requires an open scene."
	params_schema = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "default": "Player"},
			"parent": {"type": "string", "default": "."},
			"sprite_frames": {"type": "string", "description": "SpriteFrames .tres path — makes the character animated (preferred)."},
			"sprite_texture": {"type": "string", "description": "Static texture path; ignored when sprite_frames is given."},
			"with_camera": {"type": "boolean", "default": true},
			"save": {"type": "boolean", "default": true},
		},
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var root: Node = ctx.scene_root()
	var char_name := String(params["name"])
	var notes := []

	ctx.registry.call_command("add_input_action", {"action": "move_left", "keys": ["A", "Left"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "move_right", "keys": ["D", "Right"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "jump", "keys": ["Space", "W", "Up"]}, true)

	# Visual: animated SpriteFrames > static texture > generated placeholder.
	var frames: SpriteFrames = null
	var frames_path := String(params.get("sprite_frames", ""))
	if frames_path != "":
		frames = load(frames_path) as SpriteFrames
		if frames == null:
			return R.err("FILE_NOT_FOUND",
				"'%s' is not a loadable SpriteFrames resource. Create one with create_sprite_frames first." % frames_path)
	var visual: Node2D
	var visual_size := Vector2(32, 48)
	if frames != null:
		var animated := AnimatedSprite2D.new()
		animated.name = "Sprite"
		animated.sprite_frames = frames
		var animation_names := frames.get_animation_names()
		if animation_names.size() > 0:
			var default_animation := String(animation_names[0])
			for animation_name in animation_names:
				if String(animation_name).to_lower().contains("idle"):
					default_animation = String(animation_name)
			animated.animation = StringName(default_animation)
			var first := frames.get_frame_texture(StringName(default_animation), 0)
			if first != null:
				visual_size = first.get_size()
		visual = animated
	else:
		var texture_path := String(params.get("sprite_texture", ""))
		if texture_path == "" or not ResourceLoader.exists(texture_path):
			if texture_path != "":
				notes.append("Texture '%s' not found; generated a placeholder instead." % texture_path)
			texture_path = "res://assets/generated/%s_placeholder.tres" % char_name.to_snake_case()
			if not FileAccess.file_exists(texture_path):
				var tex_result: Dictionary = ctx.registry.call_command("create_placeholder_texture",
					{"path": texture_path, "width": 32, "height": 48, "color": "cornflowerblue"}, true)
				if not tex_result.get("ok", false):
					return tex_result
				notes.append("Generated placeholder texture at %s — replace with real art later." % texture_path)
		var static_sprite := Sprite2D.new()
		static_sprite.name = "Sprite"
		static_sprite.texture = load(texture_path)
		visual_size = static_sprite.texture.get_size()
		visual = static_sprite

	var script_path := "res://scripts/%s.gd" % char_name.to_snake_case()
	if FileAccess.file_exists(script_path):
		notes.append("Reusing existing script %s." % script_path)
	else:
		var source := _animated_script() if frames != null else _static_script()
		var script_result: Dictionary = ctx.registry.call_command("create_script",
			{"path": script_path, "source": source}, true)
		if not script_result.get("ok", false):
			return script_result

	var body := CharacterBody2D.new()
	body.name = char_name
	body.add_child(visual)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = maxf(visual_size.x * 0.5, 4.0)
	capsule.height = maxf(visual_size.y, capsule.radius * 2.0)
	collision.shape = capsule
	body.add_child(collision)
	if params["with_camera"]:
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		camera.position_smoothing_enabled = true
		body.add_child(camera)
	body.set_script(load(script_path))
	parent.add_child(body, true)
	ctx.ops.set_owner_recursive(body, root)
	ctx.begin_action("AI: build_character_2d %s" % char_name)
	ctx.record_node_added(parent, body)
	ctx.end_action()

	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)
	elif params["save"]:
		notes.append("Scene has no file yet — call save_scene with a save_path to persist it.")

	return R.ok({
		"character": ctx.summarize_node(body),
		"animated": frames != null,
		"script": script_path,
		"input_actions": ["move_left", "move_right", "jump"],
		"notes": notes,
	})


func _static_script() -> String:
	return """extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed(\"jump\") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var direction := Input.get_axis(\"move_left\", \"move_right\")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
	move_and_slide()
"""


func _animated_script() -> String:
	return """extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null(\"Sprite\")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed(\"jump\") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var direction := Input.get_axis(\"move_left\", \"move_right\")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if direction:
		_sprite.flip_h = direction < 0.0
	var target := \"idle\"
	if not is_on_floor():
		target = \"jump\"
	elif absf(velocity.x) > 10.0:
		target = \"run\"
	if not _sprite.sprite_frames.has_animation(target):
		return
	if _sprite.animation != StringName(target) or not _sprite.is_playing():
		_sprite.play(target)
"""
