@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "setup_ui_screen"
	description = "Scaffold a UI layer in the current scene: kind \"main_menu\" builds a centered title + Start/Quit buttons, kind \"hud\" builds a top-left score label. Structure: CanvasLayer > full-rect Control > widgets. One Ctrl+Z undoes it."
	params_schema = {
		"type": "object",
		"properties": {
			"kind": {"type": "string", "enum": ["main_menu", "hud"], "default": "main_menu"},
			"title": {"type": "string", "default": "My Game"},
			"save": {"type": "boolean", "default": true},
		},
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var root: Node = ctx.scene_root()
	if root == null:
		return R.err("NO_OPEN_SCENE", "No scene is open. Use new_scene first.")
	var kind := String(params["kind"])

	var layer := CanvasLayer.new()
	layer.name = "MainMenu" if kind == "main_menu" else "HUD"
	var control := Control.new()
	control.name = "Root"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(control)

	if kind == "main_menu":
		var center := CenterContainer.new()
		center.name = "CenterContainer"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		var vbox := VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.add_theme_constant_override("separation", 16)
		var title := Label.new()
		title.name = "Title"
		title.text = String(params["title"])
		title.add_theme_font_size_override("font_size", 48)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)
		var start := Button.new()
		start.name = "StartButton"
		start.text = "Start"
		vbox.add_child(start)
		var quit := Button.new()
		quit.name = "QuitButton"
		quit.text = "Quit"
		vbox.add_child(quit)
		center.add_child(vbox)
		control.add_child(center)
	else:
		var margin := MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 16)
		var score := Label.new()
		score.name = "ScoreLabel"
		score.text = "Score: 0"
		score.add_theme_font_size_override("font_size", 24)
		margin.add_child(score)
		control.add_child(margin)

	root.add_child(layer, true)
	ctx.ops.set_owner_recursive(layer, root)
	ctx.begin_action("AI: setup_ui_screen %s" % kind)
	ctx.record_node_added(root, layer)
	ctx.end_action()

	if params["save"] and root.scene_file_path != "":
		ctx.registry.call_command("save_scene", {}, true)

	return R.ok({
		"ui_root": ctx.summarize_node(layer),
		"note": "Buttons are not wired yet — use connect_signal to hook StartButton.pressed to a script method.",
	})
