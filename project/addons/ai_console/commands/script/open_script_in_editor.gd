@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "open_script_in_editor"
	description = "Open a script file in the editor's Script view so the user can see it, optionally jumping to a line."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"line": {"type": "integer", "default": 0},
		},
		"required": ["path"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path := String(params["path"])
	var script := load(path) as Script
	if script == null:
		return R.err("FILE_NOT_FOUND", "'%s' is not a loadable script." % path)
	EditorInterface.edit_script(script, int(params["line"]))
	EditorInterface.set_main_screen_editor("Script")
	return R.ok({"path": path})
