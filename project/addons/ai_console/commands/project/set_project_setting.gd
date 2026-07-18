@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")


func _init() -> void:
	name = "set_project_setting"
	description = "Write a project setting and save project.godot. Affects the whole project (window size, physics, rendering...), so it requires approval. Not undoable via Ctrl+Z — set it back explicitly if needed."
	params_schema = {
		"type": "object",
		"properties": {
			"setting": {"type": "string", "description": "Full setting path like display/window/size/viewport_width."},
			"value": {"description": "New value (JSON, or a Godot literal string like \"Vector2i(1280, 720)\")."},
		},
		"required": ["setting", "value"],
	}
	undoable = false
	destructive = true


func execute(params: Dictionary, _ctx) -> Dictionary:
	var setting := String(params["setting"])
	var value: Variant = params.get("value")
	if typeof(value) == TYPE_STRING:
		var parsed: Variant = str_to_var(String(value))
		if parsed != null and not String(value).begins_with("res://"):
			value = parsed
	var previous: Variant = ProjectSettings.get_setting(setting) if ProjectSettings.has_setting(setting) else null
	ProjectSettings.set_setting(setting, value)
	var err := ProjectSettings.save()
	if err != OK:
		return R.err("SAVE_FAILED", "Setting was applied in memory but project.godot could not be saved (error %d)." % err)
	return R.ok({
		"setting": setting,
		"previous": Codec.encode(previous),
		"value": Codec.encode(ProjectSettings.get_setting(setting)),
	})
