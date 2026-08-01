extends CharacterBody2D
## 外卖员:A/D 移动,空格跳。塔越高跳得越矮、加减速的惯性越要小心。

const SPEED := 270.0
const ACCEL := 1500.0
const JUMP_VELOCITY := -440.0

var stack: Node2D
var main: Node2D
var _stunned_until_ms := 0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var stunned := Time.get_ticks_msec() < _stunned_until_ms
	var direction := 0.0 if stunned else Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * SPEED, ACCEL * delta)
	if not stunned and Input.is_action_just_pressed("jump") and is_on_floor():
		var penalty := 0.0
		if stack != null:
			penalty = clampf(stack.count() * 0.045, 0.0, 0.45)
		velocity.y = JUMP_VELOCITY * (1.0 - penalty)
	var was_airborne := not is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if was_airborne and is_on_floor() and stack != null:
		stack.on_landed(absf(fall_speed))


func hit_by_car(direction: float) -> void:
	_stunned_until_ms = Time.get_ticks_msec() + 500
	velocity = Vector2(260.0 * direction, -300.0)
	if stack != null:
		stack.scatter_all("被车撞了!")
	if main != null:
		main.show_message("哎哟!过马路要看车啊!")
