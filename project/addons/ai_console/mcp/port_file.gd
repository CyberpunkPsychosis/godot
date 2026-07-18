@tool
extends RefCounted
## Publishes the MCP server's port so the stdio bridge can find the right
## editor instance: one file inside the project (.godot/, gitignored by
## convention) and one in the editor config dir keyed by project path hash
## (lets the bridge pick among multiple open editors).


static func _global_dir() -> String:
	return EditorInterface.get_editor_paths().get_config_dir().path_join("ai_console_ports")


static func _global_file() -> String:
	var key := ProjectSettings.globalize_path("res://").md5_text()
	return _global_dir().path_join(key + ".json")


static func write(port: int) -> void:
	var payload := JSON.stringify({
		"port": port,
		"pid": OS.get_process_id(),
		"project": ProjectSettings.globalize_path("res://"),
		"server": "godot-ai-console",
	})
	var local := FileAccess.open("res://.godot/ai_console_port.json", FileAccess.WRITE)
	if local != null:
		local.store_string(payload)
		local.close()
	DirAccess.make_dir_recursive_absolute(_global_dir())
	var global := FileAccess.open(_global_file(), FileAccess.WRITE)
	if global != null:
		global.store_string(payload)
		global.close()


static func clear() -> void:
	var local_path := ProjectSettings.globalize_path("res://.godot/ai_console_port.json")
	if FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(local_path)
	var global_path := _global_file()
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
