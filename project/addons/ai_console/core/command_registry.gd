@tool
extends RefCounted
## Single source of truth for every editor capability. Commands are discovered
## from addons/ai_console/commands/** and exposed identically to MCP clients
## (tools/list) and the built-in chat's LLM tool-use loop.

const R := preload("res://addons/ai_console/core/command_result.gd")
const Schema := preload("res://addons/ai_console/core/json_schema.gd")

signal command_executed(command_name: String, params: Dictionary, result: Dictionary)
## request = {"command": String, "params": Dictionary, "approval": AsyncResult}
## The UI resolves `approval` with {"approved": bool}.
signal approval_requested(request: Dictionary)

const COMMANDS_ROOT := "res://addons/ai_console/commands"

var ctx  # command_context.gd (may be null for docs generation)
var commands: Dictionary = {}
var auto_approve := false


func setup(context) -> Array[String]:
	ctx = context
	if ctx != null:
		ctx.registry = self
	return _load_dir(COMMANDS_ROOT)


func _load_dir(path: String) -> Array[String]:
	var errors: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return ["Cannot open commands directory: " + path]
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				errors.append_array(_load_dir(full))
		elif entry.ends_with(".gd"):
			var script: GDScript = load(full)
			if script == null:
				errors.append("Failed to load command script: " + full)
			else:
				var cmd = script.new()
				if cmd.name == "":
					errors.append("Command script declares no name: " + full)
				elif commands.has(cmd.name):
					errors.append("Duplicate command name '%s' in %s" % [cmd.name, full])
				else:
					commands[cmd.name] = cmd
		entry = dir.get_next()
	dir.list_dir_end()
	return errors


func list_tools() -> Array:
	var tools := []
	var names := commands.keys()
	names.sort()
	for cmd_name in names:
		var cmd = commands[cmd_name]
		tools.append({
			"name": cmd.name,
			"description": cmd.description,
			"inputSchema": cmd.params_schema,
		})
	return tools


## Executes a command. May return {"__pending": AsyncResult} when the command
## is long-running or awaits user approval; callers must handle both shapes.
func call_command(command_name: String, params: Dictionary, skip_guard := false) -> Dictionary:
	if not commands.has(command_name):
		var names := commands.keys()
		names.sort()
		var unknown := R.err("UNKNOWN_COMMAND",
			"Unknown command '%s'. Available commands: %s" % [command_name, ", ".join(PackedStringArray(names))])
		command_executed.emit(command_name, params, unknown)
		return unknown
	var cmd = commands[command_name]
	var filled: Dictionary = Schema.apply_defaults(cmd.params_schema, params)
	var schema_error: String = Schema.validate(cmd.params_schema, filled)
	if schema_error != "":
		var invalid := R.err("SCHEMA_INVALID", schema_error, {"expected_schema": cmd.params_schema})
		command_executed.emit(command_name, params, invalid)
		return invalid
	if not skip_guard and not auto_approve and cmd.is_destructive(filled, ctx):
		return _request_approval(cmd, filled)
	return _execute(cmd, filled)


func _request_approval(cmd, params: Dictionary) -> Dictionary:
	var pending = ctx.make_async()
	var approval = ctx.make_async()
	approval.resolved.connect(func(res: Dictionary) -> void:
		if res.get("approved", false):
			var exec_result: Dictionary = _execute(cmd, params)
			if exec_result.has("__pending"):
				exec_result["__pending"].resolved.connect(func(r: Dictionary) -> void:
					pending.resolve(r)
				)
			else:
				pending.resolve(exec_result)
		else:
			pending.resolve(R.err("DENIED_BY_USER",
				"The user denied the '%s' operation. Explain what you wanted to do and ask how to proceed." % cmd.name))
	)
	approval_requested.emit({"command": cmd.name, "params": params, "approval": approval})
	return {"__pending": pending}


func _execute(cmd, params: Dictionary) -> Dictionary:
	var result: Dictionary = cmd.execute(params, ctx)
	if result.has("__pending"):
		result["__pending"].resolved.connect(func(r: Dictionary) -> void:
			command_executed.emit(cmd.name, params, r)
		)
		return result
	command_executed.emit(cmd.name, params, result)
	return result
