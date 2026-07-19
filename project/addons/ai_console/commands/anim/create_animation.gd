@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Codec := preload("res://addons/ai_console/core/value_codec.gd")
const NodeResolver := preload("res://addons/ai_console/core/node_resolver.gd")


func _init() -> void:
	name = "create_animation"
	description = "Create a keyframe animation on an AnimationPlayer programmatically (doors opening, UI fades, moving platforms, simple cutscenes). Each track animates one property of one node with [time, value] keys, e.g. tracks=[{\"node\":\"Door\",\"property\":\"position\",\"keys\":[{\"time\":0,\"value\":[0,0]},{\"time\":1.5,\"value\":[0,-96]}]}]. If the AnimationPlayer does not exist yet, create it first with create_node. Values use the same coercion as set_property."
	params_schema = {
		"type": "object",
		"properties": {
			"player_path": {"type": "string", "description": "AnimationPlayer node path."},
			"animation": {"type": "string", "description": "Animation name, e.g. open_door."},
			"length": {"type": "number", "default": 1.0},
			"loop": {"type": "boolean", "default": false},
			"tracks": {"type": "array", "items": {"type": "object"}, "description": "[{node, property, keys:[{time, value}]}]"},
		},
		"required": ["player_path", "animation", "tracks"],
	}
	undoable = false


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["player_path"]))
	if not resolved.get("ok", false):
		return resolved
	var player := resolved["node"] as AnimationPlayer
	if player == null:
		return R.err("NOT_A_PLAYER",
			"Node is not an AnimationPlayer. Create one with create_node {\"type\": \"AnimationPlayer\"} first.")
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		root = player.get_parent()
	var animation := Animation.new()
	animation.length = float(params["length"])
	if params["loop"]:
		animation.loop_mode = Animation.LOOP_LINEAR
	var track_summaries := []
	for track in params["tracks"]:
		var target_result: Dictionary = ctx.resolve_node(String(track.get("node", ".")))
		if not target_result.get("ok", false):
			return target_result
		var target: Node = target_result["node"]
		var property := String(track.get("property", ""))
		if property == "" or not Codec.has_property(target, property):
			return R.err("PROPERTY_UNKNOWN",
				"Track target '%s' has no property '%s'. Use list_properties." % [target.name, property])
		var track_index := animation.add_track(Animation.TYPE_VALUE)
		var relative := String(root.get_path_to(target))
		animation.track_set_path(track_index, NodePath(relative + ":" + property))
		var keys: Array = track.get("keys", [])
		if keys.is_empty():
			return R.err("SCHEMA_INVALID", "Track for '%s:%s' has no keys." % [target.name, property])
		for key in keys:
			var decoded: Dictionary = Codec.decode(key.get("value"), target, property)
			if not decoded["ok"]:
				return R.err("VALUE_INVALID", String(decoded["message"]))
			animation.track_insert_key(track_index, float(key.get("time", 0.0)), decoded["value"])
		track_summaries.append("%s:%s (%d keys)" % [relative, property, keys.size()])
	var animation_name := String(params["animation"])
	var library: AnimationLibrary
	if player.has_animation_library(""):
		library = player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	if library.has_animation(animation_name):
		library.remove_animation(animation_name)
	var err := library.add_animation(animation_name, animation)
	if err != OK:
		return R.err("ADD_FAILED", "Could not add animation (error %d)." % err)
	EditorInterface.mark_scene_as_unsaved()
	return R.ok({
		"player": ctx.summarize_node(player),
		"animation": animation_name,
		"length": animation.length,
		"tracks": track_summaries,
		"note": "Preview with play_animation; trigger from a script with $%s.play(\"%s\")." % [NodeResolver.path_of(player, ctx.scene_root()), animation_name],
	})
