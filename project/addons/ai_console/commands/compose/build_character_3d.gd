@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "build_character_3d"
	description = "Build a complete, playable 3D character in one step: CharacterBody3D + capsule mesh + capsule collision + SpringArm3D with Camera3D, plus a WASD movement script and input actions. One Ctrl+Z undoes everything. Requires an open 3D scene (root Node3D)."
	params_schema = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "default": "Player"},
			"parent": {"type": "string", "default": "."},
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

	var script_path := "res://scripts/%s.gd" % char_name.to_snake_case()
	if FileAccess.file_exists(script_path):
		notes.append("Reusing existing script %s." % script_path)
	else:
		var script_result: Dictionary = ctx.registry.call_command("create_script",
			{"path": script_path, "source": _movement_script()}, true)
		if not script_result.get("ok", false):
			return script_result

	var body := CharacterBody3D.new()
	body.name = char_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var capsule_mesh := CapsuleMesh.new()
	mesh_instance.mesh = capsule_mesh
	mesh_instance.position = Vector3(0, 1, 0)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	collision.shape = capsule_shape
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

	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)
	elif params["save"]:
		notes.append("Scene has no file yet — call save_scene with a save_path to persist it.")

	return R.ok({
		"character": ctx.summarize_node(body),
		"script": script_path,
		"input_actions": ["move_left", "move_right", "move_forward", "move_back", "jump"],
		"notes": notes,
	})


func _movement_script() -> String:
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
