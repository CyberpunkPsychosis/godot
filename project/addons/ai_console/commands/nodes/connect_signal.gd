@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "connect_signal"
	description = "Connect a signal of one node to a method on another node's script, persisted into the saved scene (like the editor's Node > Signals dock). The target method should exist in the target's script; create it with edit_script first if needed. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"source": {"type": "string", "description": "Node path emitting the signal."},
			"signal_name": {"type": "string", "description": "e.g. pressed, body_entered, timeout."},
			"target": {"type": "string", "description": "Node path whose script has the handler method."},
			"method": {"type": "string", "description": "Handler method name, e.g. _on_button_pressed."},
		},
		"required": ["source", "signal_name", "target", "method"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var source_result: Dictionary = ctx.resolve_node(String(params["source"]))
	if not source_result.get("ok", false):
		return source_result
	var target_result: Dictionary = ctx.resolve_node(String(params["target"]))
	if not target_result.get("ok", false):
		return target_result
	var source: Node = source_result["node"]
	var target: Node = target_result["node"]
	var signal_name := String(params["signal_name"])
	var method := String(params["method"])
	if not source.has_signal(signal_name):
		var signals := []
		for info in source.get_signal_list():
			signals.append(String(info.name))
			if signals.size() >= 40:
				break
		return R.err("SIGNAL_UNKNOWN",
			"Node '%s' (%s) has no signal '%s'. Its signals include: %s" % [source.name, source.get_class(), signal_name, str(signals)])
	if source.is_connected(signal_name, Callable(target, method)):
		return R.err("ALREADY_CONNECTED", "That connection already exists.")
	if not target.has_method(method):
		return R.err("METHOD_MISSING",
			"Target '%s' has no method '%s'. Attach or edit its script to add the handler first (the connection would break at runtime otherwise)." % [target.name, method])
	ctx.ops.connect_persist(source, signal_name, target, method)
	ctx.begin_action("AI: connect_signal")
	var ur: EditorUndoRedoManager = ctx.undo_redo()
	ur.add_do_method(ctx.ops, "connect_persist", source, signal_name, target, method)
	ur.add_undo_method(ctx.ops, "disconnect_persist", source, signal_name, target, method)
	ctx.end_action()
	return R.ok({
		"source": ctx.summarize_node(source),
		"signal": signal_name,
		"target": ctx.summarize_node(target),
		"method": method,
	})
