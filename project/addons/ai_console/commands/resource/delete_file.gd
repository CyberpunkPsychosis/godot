@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "delete_file"
	description = "Delete a project file (moved to the OS trash, so it is recoverable). Always requires approval unless auto-approve is enabled."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
		},
		"required": ["path"],
	}
	undoable = false
	destructive = true


func execute(params: Dictionary, _ctx) -> Dictionary:
	var path := String(params["path"])
	if not path.begins_with("res://") or path.contains(".."):
		return R.err("INVALID_PATH", "path must be inside res://")
	if not FileAccess.file_exists(path):
		return R.err("FILE_NOT_FOUND", "'%s' does not exist." % path)
	var err := OS.move_to_trash(ProjectSettings.globalize_path(path))
	if err != OK:
		return R.err("DELETE_FAILED", "Could not delete '%s' (error %d)." % [path, err])
	EditorInterface.get_resource_filesystem().scan()
	return R.ok({"deleted": path, "note": "Moved to OS trash (recoverable)."})
