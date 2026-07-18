@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "rescan_filesystem"
	description = "Trigger a rescan of the project filesystem so externally added files appear in the FileSystem dock. The scan is asynchronous; imported assets may take a moment to become loadable."
	params_schema = {"type": "object", "properties": {}}
	undoable = false


func execute(_params: Dictionary, _ctx) -> Dictionary:
	EditorInterface.get_resource_filesystem().scan()
	return R.ok({"note": "Rescan started (asynchronous)."})
