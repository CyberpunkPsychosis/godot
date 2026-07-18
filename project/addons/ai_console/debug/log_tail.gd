@tool
extends RefCounted
## Tails the running game's log file (user://logs/godot.log — inside the
## editor, user:// maps to the project's user data dir, which is where the
## played game writes) and extracts error lines so AIs can read runtime
## failures via get_runtime_errors / wait_for_errors.
## Requires debug/file_logging/enable_file_logging=true in project settings
## (enabled in the shipped template project).

const MAX_ENTRIES := 500
const POLL_INTERVAL_MSEC := 500

var total_seen := 0

var _log_path := ""
var _offset := 0
var _entries: Array[String] = []
var _last_poll_msec := 0
var _pending_context := ""


func _init() -> void:
	_log_path = ProjectSettings.globalize_path("user://logs/godot.log")


func poll() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_poll_msec < POLL_INTERVAL_MSEC:
		return
	_last_poll_msec = now
	if not FileAccess.file_exists(_log_path):
		return
	var file := FileAccess.open(_log_path, FileAccess.READ)
	if file == null:
		return
	var length := file.get_length()
	if length < _offset:
		_offset = 0  # New game run rotated/recreated the log.
	if length == _offset:
		file.close()
		return
	file.seek(_offset)
	var new_text := file.get_buffer(length - _offset).get_string_from_utf8()
	_offset = length
	file.close()
	_parse(new_text)


func _parse(text: String) -> void:
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("at:") or stripped.begins_with("<C++ "):
			if _pending_context != "":
				_amend_last("  " + stripped)
			continue
		_pending_context = ""
		if stripped.begins_with("SCRIPT ERROR:") or stripped.begins_with("ERROR:") \
				or stripped.begins_with("USER ERROR:") or stripped.begins_with("USER SCRIPT ERROR:"):
			_push(stripped)
			_pending_context = stripped


func _push(entry: String) -> void:
	_entries.append(entry)
	total_seen += 1
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func _amend_last(context: String) -> void:
	if not _entries.is_empty():
		_entries[_entries.size() - 1] += "\n" + context


func get_recent(max_count: int) -> Array:
	var start := maxi(0, _entries.size() - max_count)
	return _entries.slice(start)


func errors_since(start_count: int) -> Array:
	var new_count := total_seen - start_count
	if new_count <= 0:
		return []
	var start := maxi(0, _entries.size() - new_count)
	return _entries.slice(start)
