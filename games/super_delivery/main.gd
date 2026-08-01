extends Node2D
## 《超级外卖员》原型关卡:取餐 → 顶着越叠越高的货 → 跳路障、钻矮桥、
## 躲汽车 → 送到客户手里拿小费。R 重开。
## 整个场景纯代码构建(零素材依赖),方便在 AI 控制台里继续迭代。

const GROUND_Y := 560.0
const LEVEL_END := 2600.0

var player: CharacterBody2D
var stack: Node2D
var camera: Camera2D
var hud_label: Label
var msg_label: Label
var tips := 0
var delivered := 0
var finished := false

var _msg_tween: Tween
var _car_timer: Timer


func _ready() -> void:
	_build_background()
	_build_ground()
	_build_player()
	_build_route()
	_build_hud()
	show_message("接单啦!去餐厅取货,送到街尾的客户家!")


func _process(_delta: float) -> void:
	var target_zoom := clampf(1.0 - stack.count() * 0.03, 0.62, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 0.05)
	hud_label.text = "载货 %d 件   小费 ¥%d   客户还有 %dm" % [
		stack.count(), tips, maxi(0, int((LEVEL_END - 250.0 - player.position.x) / 10.0))]


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.physical_keycode == KEY_R:
		get_tree().reload_current_scene()


# --- 构建 ---------------------------------------------------------------


func _build_background() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.75, 0.92)
	sky.size = Vector2(LEVEL_END + 1600, 1400)
	sky.position = Vector2(-800, -700)
	sky.z_index = -20
	add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260719
	var x := -300.0
	while x < LEVEL_END + 400:
		var w := rng.randf_range(120, 220)
		var h := rng.randf_range(160, 420)
		var building := ColorRect.new()
		building.color = Color(0.55, 0.55, 0.62).lerp(Color(0.75, 0.7, 0.66), rng.randf())
		building.size = Vector2(w, h)
		building.position = Vector2(x, GROUND_Y - h)
		building.z_index = -10
		add_child(building)
		x += w + rng.randf_range(30, 90)


func _build_ground() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEVEL_END + 1600, 60)
	shape.shape = rect
	shape.position = Vector2(LEVEL_END * 0.5, GROUND_Y + 30)
	ground.add_child(shape)
	add_child(ground)
	var road := ColorRect.new()
	road.color = Color(0.32, 0.32, 0.35)
	road.size = Vector2(LEVEL_END + 1600, 60)
	road.position = Vector2(-800, GROUND_Y)
	add_child(road)


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://player.gd"))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 72)
	shape.shape = rect
	player.add_child(shape)
	var torso := ColorRect.new()
	torso.color = Color(0.98, 0.75, 0.2)  # 外卖服黄
	torso.size = Vector2(36, 44)
	torso.position = Vector2(-18, -8)
	player.add_child(torso)
	var head := ColorRect.new()
	head.color = Color(0.98, 0.85, 0.72)
	head.size = Vector2(28, 26)
	head.position = Vector2(-14, -34)
	player.add_child(head)
	var helmet := ColorRect.new()
	helmet.color = Color(0.95, 0.6, 0.1)
	helmet.size = Vector2(32, 10)
	helmet.position = Vector2(-16, -38)
	player.add_child(helmet)
	var legs := ColorRect.new()
	legs.color = Color(0.25, 0.3, 0.45)
	legs.size = Vector2(36, 12)
	legs.position = Vector2(-18, 24)
	player.add_child(legs)
	stack = Node2D.new()
	stack.set_script(load("res://stack.gd"))
	stack.position = Vector2(0, -38)
	stack.main = self
	player.add_child(stack)
	player.stack = stack
	player.main = self
	camera = Camera2D.new()
	camera.position = Vector2(120, -120)
	player.add_child(camera)
	player.position = Vector2(120, GROUND_Y - 36)
	add_child(player)


func _build_route() -> void:
	_sign(60, "A/D 移动  空格 跳  R 重开")
	# 餐厅:取货点
	_shop(280, Color(0.85, 0.4, 0.35), "老王快餐")
	_pickup(300, "box")
	_pickup(360, "box")
	_pickup(420, "pizza")
	_pickup(480, "box")
	_sign(560, "货会自动叠上头顶 →")
	# 路障
	_cone(760)
	_cone(1010)
	_pickup(1090, "milk_tea")
	_sign(1100, "奶茶很值钱,但洒了就没了!")
	# 矮桥:刮掉过高的货
	_low_bridge(1220, 1360, GROUND_Y - 132)
	# 马路:定时来车
	_sign(1500, "!! 前方过马路,小心来车 !!")
	_pickup(1620, "box")
	_cone(1860)
	_pickup(1980, "milk_tea")
	# 客户
	_shop(LEVEL_END - 200, Color(0.4, 0.6, 0.85), "客户 · 6 栋 301")
	var door := Area2D.new()
	var door_shape := CollisionShape2D.new()
	var door_rect := RectangleShape2D.new()
	door_rect.size = Vector2(60, 160)
	door_shape.shape = door_rect
	door.add_child(door_shape)
	door.position = Vector2(LEVEL_END - 200, GROUND_Y - 80)
	door.body_entered.connect(func(body: Node) -> void:
		if body == player:
			_deliver()
	)
	add_child(door)
	# 来车定时器
	_car_timer = Timer.new()
	_car_timer.wait_time = 5.0
	_car_timer.timeout.connect(_spawn_car)
	add_child(_car_timer)
	_car_timer.start()


func _shop(x: float, color: Color, title: String) -> void:
	var building := ColorRect.new()
	building.color = color
	building.size = Vector2(220, 240)
	building.position = Vector2(x - 110, GROUND_Y - 240)
	building.z_index = -5
	add_child(building)
	var awning := ColorRect.new()
	awning.color = color.darkened(0.3)
	awning.size = Vector2(240, 24)
	awning.position = Vector2(x - 120, GROUND_Y - 250)
	add_child(awning)
	_sign(x, title)


func _sign(x: float, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x - 90, GROUND_Y - 300)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	add_child(label)


func _pickup(x: float, type_id: String) -> void:
	var pickup := Area2D.new()
	pickup.set_script(load("res://pickup.gd"))
	pickup.type_id = type_id
	pickup.position = Vector2(x, GROUND_Y - 30)
	add_child(pickup)


func _cone(x: float) -> void:
	var cone := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 46)
	shape.shape = rect
	cone.add_child(shape)
	var visual := ColorRect.new()
	visual.color = Color(0.95, 0.45, 0.15)
	visual.size = Vector2(34, 46)
	visual.position = Vector2(-17, -23)
	cone.add_child(visual)
	var stripe := ColorRect.new()
	stripe.color = Color.WHITE
	stripe.size = Vector2(34, 8)
	stripe.position = Vector2(-17, -8)
	cone.add_child(stripe)
	cone.position = Vector2(x, GROUND_Y - 23)
	add_child(cone)


func _low_bridge(x_min: float, x_max: float, bar_y: float) -> void:
	var beam := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x_max - x_min, 22)
	shape.shape = rect
	beam.add_child(shape)
	var visual := ColorRect.new()
	visual.color = Color(0.5, 0.36, 0.25)
	visual.size = Vector2(x_max - x_min, 22)
	visual.position = Vector2(-(x_max - x_min) * 0.5, -11)
	beam.add_child(visual)
	beam.position = Vector2((x_min + x_max) * 0.5, bar_y)
	add_child(beam)
	for post_x in [x_min, x_max]:
		var post := ColorRect.new()
		post.color = Color(0.45, 0.32, 0.22)
		post.size = Vector2(14, GROUND_Y - bar_y)
		post.position = Vector2(post_x - 7, bar_y)
		add_child(post)
	stack.bars.append({"x_min": x_min - 10, "x_max": x_max + 10, "y": bar_y + 11})
	_sign((x_min + x_max) * 0.5, "矮桥!叠太高过不去")


func _spawn_car() -> void:
	if finished or player.position.x < 1150 or player.position.x > 2150:
		return
	var car := Area2D.new()
	car.set_script(load("res://car.gd"))
	car.position = Vector2(camera.get_screen_center_position().x + 900, GROUND_Y - 32)
	add_child(car)
	show_message("嘀嘀——!有车!")


# --- 流程 ---------------------------------------------------------------


func _deliver() -> void:
	if finished or stack.count() == 0:
		if stack.count() == 0 and not finished:
			show_message("手上没货呢,回去捡吧!")
		return
	var Stack := load("res://stack.gd")
	var order_tips := 0
	for entry in stack.items:
		order_tips += int(Stack.TYPES[entry["type_id"]]["tip"])
		(entry["visual"] as Node2D).queue_free()
	delivered += stack.items.size()
	stack.items.clear()
	tips += order_tips
	finished = true
	_car_timer.stop()
	show_message("送达 %d 件!小费 ¥%d!按 R 再送一单" % [delivered, order_tips])
	on_stack_changed()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud_label = Label.new()
	hud_label.position = Vector2(24, 16)
	hud_label.add_theme_font_size_override("font_size", 24)
	hud.add_child(hud_label)
	msg_label = Label.new()
	msg_label.position = Vector2(0, 70)
	msg_label.custom_minimum_size = Vector2(1280, 0)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 30)
	msg_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	msg_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	msg_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(msg_label)
	add_child(hud)


func show_message(text: String) -> void:
	msg_label.text = text
	msg_label.modulate = Color.WHITE
	if _msg_tween != null:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.6)
	_msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.8)


func on_stack_changed() -> void:
	pass  # HUD 与镜头都在 _process 里持续刷新;留作扩展挂点
