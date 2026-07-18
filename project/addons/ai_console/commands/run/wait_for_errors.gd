@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "wait_for_errors"
	description = "Let the game run for N seconds, then report any runtime errors that appeared during that window. Ideal closed loop: play_scene -> wait_for_errors -> fix -> repeat."
	params_schema = {
		"type": "object",
		"properties": {
			"seconds": {"type": "number", "default": 5},
		},
	}
	undoable = false
	long_running = true


func execute(params: Dictionary, ctx) -> Dictionary:
	var tail = ctx.plugin.log_tail
	if tail == null:
		return R.err("UNAVAILABLE", "Log capture is not active.")
	var async = ctx.make_async()
	var start_count: int = tail.total_seen
	var seconds := clampf(float(params["seconds"]), 0.5, 60.0)
	var timer: SceneTreeTimer = ctx.plugin.get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		async.resolve(R.ok({
			"errors": tail.errors_since(start_count),
			"still_running": EditorInterface.is_playing_scene(),
			"waited_seconds": seconds,
		}))
	)
	return {"__pending": async}
