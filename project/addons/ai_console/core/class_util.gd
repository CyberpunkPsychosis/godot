@tool
extends RefCounted
## ClassDB helpers shared by node/resource commands.

const R := preload("res://addons/ai_console/core/command_result.gd")


## Returns an error envelope if `type` is not an instantiable class inheriting
## `must_inherit`, otherwise an empty Dictionary.
static func check_instantiable(type: String, must_inherit: String) -> Dictionary:
	if not ClassDB.class_exists(type):
		return R.err("CLASS_UNKNOWN",
			"Class '%s' does not exist. Similar classes: %s. Use search_classes to explore." % [type, str(suggest(type))])
	if must_inherit != "" and not ClassDB.is_parent_class(type, must_inherit):
		return R.err("CLASS_MISMATCH", "Class '%s' does not inherit %s." % [type, must_inherit])
	if not ClassDB.can_instantiate(type):
		return R.err("CLASS_ABSTRACT",
			"Class '%s' cannot be instantiated (abstract or editor-internal). Similar classes: %s" % [type, str(suggest(type))])
	return {}


static func suggest(query: String, limit: int = 8) -> Array[String]:
	var out: Array[String] = []
	var lowered := query.to_lower()
	for cls in ClassDB.get_class_list():
		if String(cls).to_lower().contains(lowered):
			out.append(String(cls))
			if out.size() >= limit:
				break
	return out
