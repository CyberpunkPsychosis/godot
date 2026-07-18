@tool
extends Node
## Persistent helper node whose methods are the targets of every
## EditorUndoRedoManager do/undo call registered by AI commands.
## It must outlive the undo history entries, so the plugin keeps it as a child
## for the whole session. Do-methods never free nodes (references are kept by
## the undo actions via add_do_reference/add_undo_reference).


func attach(parent: Node, node: Node, new_owner: Node, index: int = -1) -> void:
	if node.get_parent() == null:
		parent.add_child(node)
	if index >= 0 and index < parent.get_child_count():
		parent.move_child(node, index)
	set_owner_recursive(node, new_owner)


func detach(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)


func reparent_node(node: Node, new_parent: Node, index: int, keep_global: bool, new_owner: Node) -> void:
	if node.get_parent() == null:
		new_parent.add_child(node)
	elif node.get_parent() != new_parent:
		node.reparent(new_parent, keep_global)
	if index >= 0 and index < new_parent.get_child_count():
		new_parent.move_child(node, index)
	set_owner_recursive(node, new_owner)


func set_prop(obj: Object, prop: String, value: Variant) -> void:
	if prop.contains(":"):
		obj.set_indexed(NodePath(prop), value)
	else:
		obj.set(prop, value)


func add_group(node: Node, group: String) -> void:
	node.add_to_group(group, true)


func remove_group(node: Node, group: String) -> void:
	node.remove_from_group(group)


func connect_persist(source: Node, signal_name: String, target: Node, method: String) -> void:
	var callable := Callable(target, method)
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable, Object.CONNECT_PERSIST)


func disconnect_persist(source: Node, signal_name: String, target: Node, method: String) -> void:
	var callable := Callable(target, method)
	if source.is_connected(signal_name, callable):
		source.disconnect(signal_name, callable)


## Sets ownership so nodes persist when the scene is saved. Instanced scene
## roots keep their internal ownership; only the instance root itself is owned.
func set_owner_recursive(node: Node, new_owner: Node) -> void:
	if node != new_owner:
		node.owner = new_owner
	if node.scene_file_path != "" and node != new_owner:
		return
	for child in node.get_children():
		set_owner_recursive(child, new_owner)
