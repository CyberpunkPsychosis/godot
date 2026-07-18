@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "build_character_2d"
	description = "Build a complete, playable 2D character in one step: CharacterBody2D + Sprite2D (placeholder texture generated if no art is given) + CollisionShape2D sized to the sprite + optional Camera2D, plus a WASD/arrows platformer movement script and the move_left/move_right/jump input actions. One Ctrl+Z undoes the whole character. Requires an open scene."
	params_schema = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "default": "Player"},
			"parent": {"type": "string", "default": "."},
			"sprite_texture": {"type": "string", "description": "Optional res:// texture path; a placeholder is generated when omitted."},
			"with_camera": {"type": "boolean", "default": true},
			"save": {"type": "boolean", "default": true, "description": "Save the scene afterwards."},
		},
	}
	long_running = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var parent_result: Dictionary = ctx.resolve_node(String(params["parent"]))
	if not parent_result.get("ok", false):
		return parent_result
	var parent: Node = parent_result["node"]
	var root: Node = ctx.scene_root()
	var char_name := String(params["name"])
	var notes := []

	# 1. Texture: provided or generated placeholder.
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
	var texture: Texture2D = load(texture_path)

	# 2. Input actions (project-level, done before the script needs them).
	ctx.registry.call_command("add_input_action", {"action": "move_left", "keys": ["A", "Left"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "move_right", "keys": ["D", "Right"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "jump", "keys": ["Space", "W", "Up"]}, true)

	# 3. Movement script.
	var script_path := "res://scripts/%s.gd" % char_name.to_snake_case()
	if FileAccess.file_exists(script_path):
		notes.append("Reusing existing script %s." % script_path)
	else:
		var script_result: Dictionary = ctx.registry.call_command("create_script",
			{"path": script_path, "source": _movement_script()}, true)
		if not script_result.get("ok", false):
			return script_result

	# 4. Node hierarchy, all inside one undo action.
	var body := CharacterBody2D.new()
	body.name = char_name
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	body.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	var tex_size: Vector2 = texture.get_size()
	capsule.radius = maxf(tex_size.x * 0.5, 4.0)
	capsule.height = maxf(tex_size.y, capsule.radius * 2.0)
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

	# 5. Save.
	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)
	elif params["save"]:
		notes.append("Scene has no file yet — call save_scene with a save_path to persist it.")

	return R.ok({
		"character": ctx.summarize_node(body),
		"children": ["Sprite2D", "CollisionShape2D", "Camera2D"] if params["with_camera"] else ["Sprite2D", "CollisionShape2D"],
		"script": script_path,
		"input_actions": ["move_left", "move_right", "jump"],
		"notes": notes,
	})


func _movement_script() -> String:
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
