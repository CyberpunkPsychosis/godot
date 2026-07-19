@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "build_character_3d"
	description = "Build a complete, playable 3D character in one step: CharacterBody3D + visual + capsule collision + SpringArm3D camera, WASD movement script and input actions. Pass model_scene (an imported .glb/.gltf with baked animations, e.g. from Quaternius or a Mixamo export) to use a real ANIMATED model — the script auto-detects idle/run/walk/jump clips and switches them while moving. Without model_scene a capsule placeholder is used. One Ctrl+Z undoes everything."
	params_schema = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "default": "Player"},
			"parent": {"type": "string", "default": "."},
			"model_scene": {"type": "string", "description": "Imported model path, e.g. res://assets/knight/knight.glb (preferred)."},
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

	ctx.registry.call_command("add_input_action", {"action": "move_left", "keys": ["A"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "move_right", "keys": ["D"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "move_forward", "keys": ["W"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "move_back", "keys": ["S"]}, true)
	ctx.registry.call_command("add_input_action", {"action": "jump", "keys": ["Space"]}, true)

	# Visual: animated model scene > capsule placeholder.
	var model: Node = null
	var model_path := String(params.get("model_scene", ""))
	if model_path != "":
		var packed: PackedScene = load(model_path) as PackedScene
		if packed == null:
			return R.err("FILE_NOT_FOUND",
				"'%s' is not a loadable model scene (if just added, run rescan_filesystem and retry)." % model_path)
		model = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		model.name = "Model"

	var script_path := "res://scripts/%s.gd" % char_name.to_snake_case()
	if FileAccess.file_exists(script_path):
		notes.append("Reusing existing script %s." % script_path)
	else:
		var source := _animated_script() if model != null else _basic_script()
		var script_result: Dictionary = ctx.registry.call_command("create_script",
			{"path": script_path, "source": source}, true)
		if not script_result.get("ok", false):
			return script_result

	var body := CharacterBody3D.new()
	body.name = char_name
	if model != null:
		body.add_child(model)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		mesh_instance.mesh = CapsuleMesh.new()
		mesh_instance.position = Vector3(0, 1, 0)
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = CapsuleShape3D.new()
	collision.position = Vector3(0, 1, 0)
	body.add_child(collision)
	if params["with_camera"]:
		var arm := SpringArm3D.new()
		arm.name = "SpringArm3D"
		arm.spring_length = 5.0
		arm.position = Vector3(0, 2, 0)
		arm.rotation_degrees = Vector3(-20, 0, 0)
		var camera := Camera3D.new()
		camera.name = "Camera3D"
		arm.add_child(camera)
		body.add_child(arm)
	body.set_script(load(script_path))
	parent.add_child(body, true)
	ctx.ops.set_owner_recursive(body, root)
	ctx.begin_action("AI: build_character_3d %s" % char_name)
	ctx.record_node_added(parent, body)
	ctx.end_action()

	var animations := []
	if model != null:
		var player := _find_animation_player(model)
		if player != null:
			for animation_name in player.get_animation_list():
				animations.append(String(animation_name))
		else:
			notes.append("The model has no AnimationPlayer — it will move but not animate.")

	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)
	elif params["save"]:
		notes.append("Scene has no file yet — call save_scene with a save_path to persist it.")

	return R.ok({
		"character": ctx.summarize_node(body),
		"animated": not animations.is_empty(),
		"animations": animations,
		"script": script_path,
		"input_actions": ["move_left", "move_right", "move_forward", "move_back", "jump"],
		"notes": notes,
	})


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _basic_script() -> String:
	return """extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed(\"jump\") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector(\"move_left\", \"move_right\", \"move_forward\", \"move_back\")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	move_and_slide()
"""


func _animated_script() -> String:
	return """extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

var _anim: AnimationPlayer
var _clip_idle := \"\"
var _clip_run := \"\"
var _clip_jump := \"\"


func _ready() -> void:
	_anim = _find_animation_player(self)
	if _anim == null:
		return
	for animation_name in _anim.get_animation_list():
		var lower := String(animation_name).to_lower()
		if _clip_idle == \"\" and lower.contains(\"idle\"):
			_clip_idle = animation_name
		if _clip_run == \"\" and (lower.contains(\"run\") or lower.contains(\"walk\")):
			_clip_run = animation_name
		if _clip_jump == \"\" and lower.contains(\"jump\"):
			_clip_jump = animation_name


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed(\"jump\") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector(\"move_left\", \"move_right\", \"move_forward\", \"move_back\")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var model := get_node_or_null(\"Model\")
		if model is Node3D:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), 12.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: Vector3) -> void:
	if _anim == null:
		return
	var target := _clip_idle
	if not is_on_floor() and _clip_jump != \"\":
		target = _clip_jump
	elif direction != Vector3.ZERO and _clip_run != \"\":
		target = _clip_run
	if target != \"\" and _anim.current_animation != target:
		_anim.play(target, 0.2)


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
"""
