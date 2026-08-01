extends Area2D
## 待取的货物:轻轻浮动,碰到就叠上头顶。

const Stack := preload("res://stack.gd")

var type_id := "box"


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	add_child(shape)
	var visual := Stack.make_visual(type_id)
	add_child(visual)
	var tween := create_tween().set_loops()
	tween.tween_property(visual, "position:y", -8.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.get("stack") != null:
		body.stack.add_item(type_id)
		if body.get("main") != null:
			body.main.show_message("+1 %s" % Stack.TYPES[type_id]["name"])
		queue_free()
