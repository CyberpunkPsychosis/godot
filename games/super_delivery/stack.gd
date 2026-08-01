extends Node2D
## 头顶货物塔:整个游戏的心脏。
## 采用"假物理":每件货是跟随锚点的运动学节点,由阻尼弹簧驱动摇摆角,
## 手感完全可调、永不炸塔;只有倒塔的瞬间才切换成真刚体散落(喜剧时刻)。

const ITEM_W := 44.0
const ITEM_H := 30.0

const TYPES := {
	"box": {"name": "外卖箱", "color": Color(0.72, 0.45, 0.2), "tip": 5, "fragile": false},
	"pizza": {"name": "披萨", "color": Color(0.85, 0.25, 0.2), "tip": 5, "fragile": false},
	"milk_tea": {"name": "奶茶", "color": Color(0.95, 0.87, 0.72), "tip": 12, "fragile": true},
}

var items: Array = []  # [{"visual": Node2D, "type_id": String}]
var sway := 0.0
var sway_vel := 0.0
var bars: Array = []  # 矮桥列表 [{"x_min", "x_max", "y"}] (全局坐标)
var main: Node2D

var _prev_vx := 0.0


func count() -> int:
	return items.size()


func add_item(type_id: String) -> void:
	var visual := make_visual(type_id)
	add_child(visual)
	visual.position = Vector2(0, -ITEM_H * (items.size() + 0.5))
	visual.scale = Vector2(1.35, 0.6)  # 落塔挤压弹一下
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	items.append({"visual": visual, "type_id": type_id})
	sway_vel += randf_range(-0.3, 0.3)
	if main != null:
		main.on_stack_changed()


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null:
		return
	# 摇摆 = 被玩家加速度激励的阻尼摆
	var accel := (player.velocity.x - _prev_vx) / maxf(delta, 0.0001)
	_prev_vx = player.velocity.x
	sway_vel += (-accel * 0.0016 - sway * 9.0 - sway_vel * 3.2) * delta
	sway += sway_vel * delta
	# 塔越高,允许的倾角越小
	var limit := deg_to_rad(maxf(34.0 - items.size() * 1.4, 15.0))
	if not items.is_empty() and absf(sway) > limit:
		scatter_from(0, "太晃了!货全散了!")
		return
	# 逐件跟随:越往上延迟越大,甩鞭子手感
	for i in range(items.size()):
		var visual: Node2D = items[i]["visual"]
		var lean := sin(sway) * float(i + 1) * 9.0
		var target := Vector2(lean, -ITEM_H * (i + 0.5))
		var k := 1.0 - exp(-14.0 * delta / (1.0 + float(i) * 0.10))
		visual.position = visual.position.lerp(target, k)
		visual.rotation = lerp_angle(visual.rotation, sway * float(i + 1) * 0.06, k)
	# 矮桥刮顶
	for bar in bars:
		if global_position.x > bar["x_min"] and global_position.x < bar["x_max"]:
			for i in range(items.size()):
				if to_global(items[i]["visual"].position).y < bar["y"]:
					scatter_from(i, "矮桥刮掉了上面的货!")
					return
			break


func on_landed(fall_speed: float) -> void:
	sway_vel += randf_range(-1.0, 1.0) * clampf(fall_speed / 900.0, 0.1, 0.9)


func scatter_all(reason: String) -> void:
	scatter_from(0, reason)


func scatter_from(index: int, reason: String) -> void:
	if index >= items.size():
		return
	var scatter_script := load("res://scatter_item.gd")
	var spilled := false
	for i in range(index, items.size()):
		var entry: Dictionary = items[i]
		var type: Dictionary = TYPES[entry["type_id"]]
		var origin: Vector2 = (entry["visual"] as Node2D).global_position
		(entry["visual"] as Node2D).queue_free()
		if type["fragile"]:
			spilled = true
			continue  # 奶茶洒了就没了
		var body: RigidBody2D = scatter_script.new()
		body.type_id = entry["type_id"]
		body.global_position = origin
		body.linear_velocity = Vector2(randf_range(-180, 180), randf_range(-320, -120))
		body.angular_velocity = randf_range(-6, 6)
		get_tree().current_scene.add_child(body)
	items.resize(index)
	sway = 0.0
	sway_vel = 0.0
	if main != null:
		main.show_message(reason + ("(奶茶洒了……)" if spilled else ""))
		main.on_stack_changed()


## 生成一件带小表情的货物视觉(纯 ColorRect,零素材依赖)
static func make_visual(type_id: String) -> Node2D:
	var type: Dictionary = TYPES[type_id]
	var root := Node2D.new()
	var body := ColorRect.new()
	body.color = type["color"]
	body.size = Vector2(ITEM_W, ITEM_H)
	body.position = Vector2(-ITEM_W * 0.5, -ITEM_H * 0.5)
	root.add_child(body)
	var lid := ColorRect.new()
	lid.color = Color(type["color"]).darkened(0.25)
	lid.size = Vector2(ITEM_W, 6)
	lid.position = Vector2(-ITEM_W * 0.5, -ITEM_H * 0.5)
	root.add_child(lid)
	for eye_x in [-9.0, 5.0]:
		var eye := ColorRect.new()
		eye.color = Color.WHITE
		eye.size = Vector2(6, 8)
		eye.position = Vector2(eye_x, -4)
		root.add_child(eye)
		var pupil := ColorRect.new()
		pupil.color = Color(0.12, 0.12, 0.14)
		pupil.size = Vector2(3, 4)
		pupil.position = Vector2(eye_x + 1.5, -1)
		root.add_child(pupil)
	return root
