@tool
extends RefCounted
## Execution context handed to every command: editor access, node resolution,
## undo/redo recording and async completion helpers.
##
## Undo pattern used across all commands: mutate the editor state directly
## first, then register symmetric do/undo methods (targeting the persistent
## `ops` node) inside begin_action()/end_action(), which commits with
## execute=false so the do-methods only run on redo. Nested begin/end calls
## (composite commands) collapse into one undo action.

const NodeResolver := preload("res://addons/ai_console/core/node_resolver.gd")
const R := preload("res://addons/ai_console/core/command_result.gd")
const AsyncResult := preload("res://addons/ai_console/core/async_result.gd")

var plugin: EditorPlugin
var ops: Node
var registry  # command_registry.gd — set by the registry itself in setup()

var _action_depth: int = 0


func undo_redo() -> EditorUndoRedoManager:
	return plugin.get_undo_redo()


func scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Returns {"ok": true, "node": Node} or an error envelope.
func resolve_node(path: String) -> Dictionary:
	var root := scene_root()
	if root == null:
		return R.err("NO_OPEN_SCENE",
			"No scene is currently being edited. Create one with new_scene or open one with open_scene first.")
	return NodeResolver.resolve(root, path)


func node_path(node: Node) -> String:
	return NodeResolver.path_of(node, scene_root())


func begin_action(action_name: String) -> void:
	if _action_depth == 0:
		undo_redo().create_action(action_name, UndoRedo.MERGE_DISABLE, scene_root())
	_action_depth += 1


func end_action() -> void:
	_action_depth -= 1
	if _action_depth == 0:
		undo_redo().commit_action(false)
		EditorInterface.mark_scene_as_unsaved()


## Node was already added to `parent`; register redo/undo for it.
func record_node_added(parent: Node, node: Node) -> void:
	var ur := undo_redo()
	ur.add_do_method(ops, "attach", parent, node, scene_root(), node.get_index())
	ur.add_do_reference(node)
	ur.add_undo_method(ops, "detach", node)


## Node was already detached from `parent`; register redo/undo for it.
func record_node_removed(parent: Node, node: Node, index: int) -> void:
	var ur := undo_redo()
	ur.add_do_method(ops, "detach", node)
	ur.add_undo_method(ops, "attach", parent, node, scene_root(), index)
	ur.add_undo_reference(node)


## Property was already changed; register redo/undo for it.
func record_property(obj: Object, prop: String, old_value: Variant, new_value: Variant) -> void:
	var ur := undo_redo()
	ur.add_do_method(ops, "set_prop", obj, prop, new_value)
	ur.add_undo_method(ops, "set_prop", obj, prop, old_value)


func make_async() -> RefCounted:
	return AsyncResult.new()


func summarize_node(node: Node) -> Dictionary:
	return {"path": node_path(node), "name": String(node.name), "type": node.get_class()}
