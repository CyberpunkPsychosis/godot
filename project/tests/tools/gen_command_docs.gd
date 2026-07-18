extends SceneTree
## Regenerates the command reference from the registry (single source of
## truth). Run headlessly:
##   godot --headless --path project --script res://tests/tools/gen_command_docs.gd
## Output: project/addons/ai_console/docs/COMMANDS.md

const Registry := preload("res://addons/ai_console/core/command_registry.gd")


func _initialize() -> void:
	var registry = Registry.new()
	var errors: Array = registry.setup(null)
	for error in errors:
		push_error(error)
	var lines := [
		"# AI Console — Command Reference",
		"",
		"Generated from the command registry (`scripts/gen_command_docs.gd`); do not edit by hand.",
		"These are the MCP tools exposed to every connected AI (external agents and the built-in chat).",
		"",
	]
	for tool in registry.list_tools():
		lines.append("## `%s`" % tool["name"])
		lines.append("")
		lines.append(String(tool["description"]))
		lines.append("")
		var props: Dictionary = tool["inputSchema"].get("properties", {})
		var required: Array = tool["inputSchema"].get("required", [])
		if props.is_empty():
			lines.append("_No parameters._")
		else:
			lines.append("| param | type | required | notes |")
			lines.append("|---|---|---|---|")
			var keys := props.keys()
			keys.sort()
			for key in keys:
				var schema: Dictionary = props[key]
				var notes := String(schema.get("description", ""))
				if schema.has("default"):
					notes += " (default: %s)" % JSON.stringify(schema["default"])
				if schema.has("enum"):
					notes += " (one of: %s)" % JSON.stringify(schema["enum"])
				lines.append("| `%s` | %s | %s | %s |" % [
					key,
					String(schema.get("type", "any")),
					"yes" if key in required else "no",
					notes.strip_edges(),
				])
		lines.append("")
	var out := FileAccess.open("res://addons/ai_console/docs/COMMANDS.md", FileAccess.WRITE)
	if out == null:
		push_error("cannot write COMMANDS.md")
		quit(1)
		return
	out.store_string("\n".join(PackedStringArray(lines)))
	out.close()
	print("wrote %d tool entries to addons/ai_console/docs/COMMANDS.md" % registry.list_tools().size())
	quit(0)
