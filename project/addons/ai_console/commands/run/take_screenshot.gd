@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "take_screenshot"
	description = "Capture the editor's 2D or 3D viewport as a PNG. Returns the saved file path and (for MCP clients that support images) the image itself, so you can visually inspect the scene layout."
	params_schema = {
		"type": "object",
		"properties": {
			"viewport": {"type": "string", "enum": ["2d", "3d"], "default": "2d"},
			"max_width": {"type": "integer", "default": 1280},
		},
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var viewport: Viewport
	if String(params["viewport"]) == "3d":
		viewport = EditorInterface.get_editor_viewport_3d(0)
	else:
		viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return R.err("UNAVAILABLE", "Editor viewport not available.")
	var image := viewport.get_texture().get_image()
	if image == null:
		return R.err("CAPTURE_FAILED", "Could not capture the viewport texture.")
	var max_width := int(params["max_width"])
	if image.get_width() > max_width:
		var scale := float(max_width) / float(image.get_width())
		image.resize(max_width, int(image.get_height() * scale), Image.INTERPOLATE_BILINEAR)
	var dir := "user://ai_console/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file_path := "%s/shot_%d.png" % [dir, Time.get_ticks_msec()]
	var save_err := image.save_png(file_path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save screenshot (error %d)." % save_err)
	var result := {
		"path": ProjectSettings.globalize_path(file_path),
		"width": image.get_width(),
		"height": image.get_height(),
	}
	var buffer := image.save_png_to_buffer()
	if buffer.size() <= 1_500_000:
		result["base64_png"] = Marshalls.raw_to_base64(buffer)
	return R.ok(result)
