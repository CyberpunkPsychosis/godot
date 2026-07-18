@tool
extends "res://addons/ai_console/core/editor_command.gd"

const NodeResolver := preload("res://addons/ai_console/core/node_resolver.gd")


func _init() -> void:
	name = "get_editor_state"
	description = "One-shot overview of the editor: Godot version, project name, currently edited scene, open scenes, selected nodes and whether the game is running. Call this first in a session to orient yourself."
	params_schema = {"type": "object", "properties": {}}
	undoable = false


func execute(_params: Dictionary, ctx) -> Dictionary:
	var version := Engine.get_version_info()
	var root: Node = ctx.scene_root()
	var selection := []
	if root != null:
		for node in EditorInterface.get_selection().get_selected_nodes():
			selection.append(NodeResolver.path_of(node, root))
	var open_scenes := []
	for scene_path in EditorInterface.get_open_scenes():
		open_scenes.append(scene_path)
	return R.ok({
		"godot_version": "%d.%d.%d" % [version.major, version.minor, version.patch],
		"project_name": String(ProjectSettings.get_setting("application/config/name", "")),
		"edited_scene": root.scene_file_path if root != null else null,
		"edited_scene_root": String(root.name) if root != null else null,
		"open_scenes": open_scenes,
		"selected_nodes": selection,
		"is_playing": EditorInterface.is_playing_scene(),
		"main_scene": String(ProjectSettings.get_setting("application/run/main_scene", "")),
	})
