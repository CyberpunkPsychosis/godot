extends SceneTree
## Headless sanity gate, run in CI as:
##   godot --headless --path project --script res://tests/smoke/headless_check.gd
## Loads every addon script (catches parse/compile errors), instantiates every
## command (catches metadata mistakes) and validates the registry contract —
## no editor window required.


func _initialize() -> void:
	var failures: Array[String] = []
	var scripts: Array[String] = []
	_collect("res://addons/ai_console", scripts)
	for path in scripts:
		var script: Variant = load(path)
		if script == null:
			failures.append("failed to load: " + path)
	print("loaded %d scripts" % scripts.size())

	var names := {}
	var command_scripts: Array[String] = []
	_collect("res://addons/ai_console/commands", command_scripts)
	for path in command_scripts:
		var script: GDScript = load(path)
		if script == null:
			continue
		var cmd: Variant = script.new()
		if String(cmd.name) == "":
			failures.append("command with empty name: " + path)
			continue
		if names.has(cmd.name):
			failures.append("duplicate command name '%s' in %s" % [cmd.name, path])
		names[cmd.name] = true
		if String(cmd.description) == "":
			failures.append("command '%s' has no description" % cmd.name)
		if String(cmd.params_schema.get("type", "")) != "object":
			failures.append("command '%s' schema is not an object schema" % cmd.name)
	print("validated %d commands" % names.size())

	if names.size() < 30:
		failures.append("expected at least 30 commands, found %d" % names.size())

	for failure in failures:
		push_error("HEADLESS CHECK FAILED: " + failure)
	print("headless check: %s" % ("PASS" if failures.is_empty() else "FAIL (%d problems)" % failures.size()))
	quit(0 if failures.is_empty() else 1)


func _collect(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
