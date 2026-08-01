extends Area2D
## 从右往左冲过来的车。撞上=货全散+击飞。跳起来躲!

var speed := 380.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(130, 62)
	shape.shape = rect
	add_child(shape)
	var body := ColorRect.new()
	body.color = Color(0.85, 0.75, 0.2)
	body.size = Vector2(130, 44)
	body.position = Vector2(-65, -22)
	add_child(body)
	var roof := ColorRect.new()
	roof.color = Color(0.75, 0.65, 0.15)
	roof.size = Vector2(70, 26)
	roof.position = Vector2(-45, -46)
	add_child(roof)
	var window := ColorRect.new()
	window.color = Color(0.6, 0.85, 0.95)
	window.size = Vector2(26, 18)
	window.position = Vector2(-38, -42)
	add_child(window)
	for wheel_x in [-40.0, 34.0]:
		var wheel := ColorRect.new()
		wheel.color = Color(0.15, 0.15, 0.17)
		wheel.size = Vector2(24, 24)
		wheel.position = Vector2(wheel_x, 12)
		add_child(wheel)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -400.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("hit_by_car"):
		body.hit_by_car(-1.0)
