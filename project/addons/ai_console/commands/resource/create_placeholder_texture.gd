@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "create_placeholder_texture"
	description = "Generate a solid-color placeholder texture (.tres, no import step needed) so sprites and UI can be built before real art exists. Returns the res:// path to use as a texture property."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "Save path like res://assets/generated/player.tres"},
			"width": {"type": "integer", "default": 32},
			"height": {"type": "integer", "default": 48},
			"color": {"type": "string", "default": "cornflowerblue", "description": "Color name or #RRGGBB."},
		},
		"required": ["path"],
	}
	undoable = false


func is_destructive(params: Dictionary, _ctx) -> bool:
	return FileAccess.file_exists(String(params.get("path", "")))


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path := String(params["path"])
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return R.err("INVALID_PATH", "path must be a res:// path ending in .tres")
	var width := clampi(int(params["width"]), 1, 2048)
	var height := clampi(int(params["height"]), 1, 2048)
	var color := Color.from_string(String(params["color"]), Color.MAGENTA)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	# Darker 1px border so the placeholder reads as a distinct object in-scene.
	var border := color.darkened(0.4)
	for x in range(width):
		image.set_pixel(x, 0, border)
		image.set_pixel(x, height - 1, border)
	for y in range(height):
		image.set_pixel(0, y, border)
		image.set_pixel(width - 1, y, border)
	var texture := PortableCompressedTexture2D.new()
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_err := ResourceSaver.save(texture, path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save texture to '%s' (error %d)." % [path, save_err])
	EditorInterface.get_resource_filesystem().update_file(path)
	return R.ok({"path": path, "width": width, "height": height})
