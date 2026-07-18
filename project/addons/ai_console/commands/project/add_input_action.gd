@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "add_input_action"
	description = "Create or extend an input action in the Input Map with keyboard keys, e.g. action \"jump\" with keys [\"Space\", \"W\"]. Character controller scripts read these via Input.is_action_pressed. Key names: letters, digits, \"Space\", \"Left\"/\"Right\"/\"Up\"/\"Down\", \"Shift\", \"Enter\", etc."
	params_schema = {
		"type": "object",
		"properties": {
			"action": {"type": "string", "description": "Action name like move_left, jump, attack."},
			"keys": {"type": "array", "items": {"type": "string"}, "description": "Key names to bind."},
			"deadzone": {"type": "number", "default": 0.5},
		},
		"required": ["action", "keys"],
	}
	undoable = false


func execute(params: Dictionary, _ctx) -> Dictionary:
	var action := String(params["action"])
	if action.is_empty() or action.contains("/"):
		return R.err("INVALID_NAME", "Action names must be simple identifiers like 'move_left'.")
	var setting := "input/" + action
	var events: Array = []
	var existing_keys := []
	if ProjectSettings.has_setting(setting):
		var current: Dictionary = ProjectSettings.get_setting(setting)
		events = current.get("events", [])
		for ev in events:
			var key_event := ev as InputEventKey
			if key_event != null:
				existing_keys.append(OS.get_keycode_string(key_event.physical_keycode))
	var bound := []
	var errors := []
	for key_name in params["keys"]:
		var keycode := OS.find_keycode_from_string(String(key_name))
		if keycode == KEY_NONE:
			errors.append("Unknown key name '%s'" % key_name)
			continue
		if OS.get_keycode_string(keycode) in existing_keys:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		events.append(event)
		bound.append(String(key_name))
	ProjectSettings.set_setting(setting, {"deadzone": float(params["deadzone"]), "events": events})
	var err := ProjectSettings.save()
	if err != OK:
		return R.err("SAVE_FAILED", "Could not save project.godot (error %d)." % err)
	var result := {"action": action, "added_keys": bound, "total_events": events.size()}
	if not errors.is_empty():
		result["errors"] = errors
	return R.ok(result)
