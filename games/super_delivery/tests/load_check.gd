extends SceneTree
## CI 用:headless 加载游戏的所有脚本与主场景,确保编译通过。


func _initialize() -> void:
	var failures := 0
	for path in ["res://main.gd", "res://player.gd", "res://stack.gd",
			"res://scatter_item.gd", "res://car.gd", "res://pickup.gd"]:
		if load(path) == null:
			push_error("failed to load " + path)
			failures += 1
	if load("res://main.tscn") == null:
		push_error("failed to load main.tscn")
		failures += 1
	print("super_delivery load check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
