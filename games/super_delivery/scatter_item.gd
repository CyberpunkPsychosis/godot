extends RigidBody2D
## 倒塔后散落在地的货物:短暂冷却后走近即可重新捡回塔上。

const Stack := preload("res://stack.gd")

var type_id := "box"

var _pickable_at_ms := 0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Stack.ITEM_W, Stack.ITEM_H)
	shape.shape = rect
	add_child(shape)
	add_child(Stack.make_visual(type_id))
	var pickup := Area2D.new()
	var pickup_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	pickup_shape.shape = circle
	pickup.add_child(pickup_shape)
	add_child(pickup)
	pickup.body_entered.connect(_on_body_entered)
	_pickable_at_ms = Time.get_ticks_msec() + 700


func _on_body_entered(body: Node) -> void:
	if Time.get_ticks_msec() < _pickable_at_ms:
		return
	if body is CharacterBody2D and body.get("stack") != null:
		body.stack.add_item(type_id)
		queue_free()
