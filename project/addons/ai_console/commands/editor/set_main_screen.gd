@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "set_main_screen"
	description = "Switch the editor's main view between 2D, 3D, Script and AssetLib — e.g. switch to 2D after building a 2D scene so the user sees the result."
	params_schema = {
		"type": "object",
		"properties": {
			"screen": {"type": "string", "enum": ["2D", "3D", "Script", "AssetLib"]},
		},
		"required": ["screen"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	EditorInterface.set_main_screen_editor(String(params["screen"]))
	return R.ok({"screen": String(params["screen"])})
