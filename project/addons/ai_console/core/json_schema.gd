@tool
extends RefCounted
## Minimal JSON Schema (draft-07 subset) validator used for command params.
## Supported keywords: type (object/string/integer/number/boolean/array),
## properties, required, enum, items, default.
## validate() returns "" when valid, otherwise a readable error string that an
## LLM can act on.


static func validate(schema: Dictionary, data: Variant, path: String = "params") -> String:
	var type_name: String = schema.get("type", "")
	match type_name:
		"object":
			if typeof(data) != TYPE_DICTIONARY:
				return "%s must be an object" % path
			for key in schema.get("required", []):
				if not data.has(key):
					return "%s is missing required field '%s'" % [path, key]
			var props: Dictionary = schema.get("properties", {})
			for key in data.keys():
				if props.has(key):
					var sub_error := validate(props[key], data[key], "%s.%s" % [path, key])
					if sub_error != "":
						return sub_error
		"string":
			if typeof(data) != TYPE_STRING:
				return "%s must be a string" % path
		"integer":
			if typeof(data) != TYPE_INT and not (typeof(data) == TYPE_FLOAT and data == floorf(data)):
				return "%s must be an integer" % path
		"number":
			if typeof(data) != TYPE_INT and typeof(data) != TYPE_FLOAT:
				return "%s must be a number" % path
		"boolean":
			if typeof(data) != TYPE_BOOL:
				return "%s must be a boolean" % path
		"array":
			if typeof(data) != TYPE_ARRAY:
				return "%s must be an array" % path
			if schema.has("items"):
				for i in range(data.size()):
					var item_error := validate(schema["items"], data[i], "%s[%d]" % [path, i])
					if item_error != "":
						return item_error
	if schema.has("enum"):
		var allowed: Array = schema["enum"]
		if not (data in allowed):
			return "%s must be one of %s (got %s)" % [path, JSON.stringify(allowed), JSON.stringify(data)]
	return ""


static func apply_defaults(schema: Dictionary, data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	var props: Dictionary = schema.get("properties", {})
	for key in props:
		var prop: Dictionary = props[key]
		if not out.has(key) and prop.has("default"):
			out[key] = prop["default"]
	return out
