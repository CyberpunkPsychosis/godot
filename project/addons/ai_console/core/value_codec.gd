@tool
extends RefCounted
## Converts between JSON-safe values (what AIs send/receive) and Godot Variants.
## Decoding is property-aware: "Vector2(3, 4)" strings, [3, 4] arrays, color
## names and res:// paths are all turned into the right Variant for the target
## property.


static func find_property_type(obj: Object, prop: String) -> int:
	var base := prop.get_slice(":", 0)
	for info in obj.get_property_list():
		if String(info.name) == base:
			if prop.contains(":"):
				return TYPE_NIL  # Subproperty: type unknown, decode best-effort.
			return info.type
	return TYPE_MAX  # Property does not exist at all.


static func has_property(obj: Object, prop: String) -> bool:
	return find_property_type(obj, prop) != TYPE_MAX


## Returns {"ok": true, "value": Variant} or {"ok": false, "message": String}.
static func decode(value: Variant, obj: Object, prop: String) -> Dictionary:
	var target := find_property_type(obj, prop)
	if target == TYPE_MAX:
		target = TYPE_NIL
	var decoded: Variant = value
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			if text.begins_with("res://"):
				if ResourceLoader.exists(text):
					decoded = load(text)
				elif target == TYPE_OBJECT:
					return {"ok": false, "message": "Resource '%s' does not exist. Use list_files to find valid paths." % text}
			elif target == TYPE_COLOR:
				decoded = Color.from_string(text, Color.MAGENTA)
			elif target != TYPE_STRING:
				var parsed: Variant = str_to_var(text)
				if parsed != null:
					decoded = parsed
		TYPE_ARRAY:
			decoded = _array_to_variant(value, target)
		TYPE_FLOAT:
			if target == TYPE_INT:
				decoded = int(value)
		TYPE_INT:
			if target == TYPE_FLOAT:
				decoded = float(value)
	return {"ok": true, "value": decoded}


static func _array_to_variant(arr: Array, target: int) -> Variant:
	var nums: Array[float] = []
	for item in arr:
		if typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT:
			nums.append(float(item))
	if nums.size() != arr.size():
		return arr
	match target:
		TYPE_VECTOR2:
			if nums.size() >= 2:
				return Vector2(nums[0], nums[1])
		TYPE_VECTOR2I:
			if nums.size() >= 2:
				return Vector2i(int(nums[0]), int(nums[1]))
		TYPE_VECTOR3:
			if nums.size() >= 3:
				return Vector3(nums[0], nums[1], nums[2])
		TYPE_VECTOR4:
			if nums.size() >= 4:
				return Vector4(nums[0], nums[1], nums[2], nums[3])
		TYPE_COLOR:
			if nums.size() == 3:
				return Color(nums[0], nums[1], nums[2])
			if nums.size() >= 4:
				return Color(nums[0], nums[1], nums[2], nums[3])
	return arr


## Converts a Variant into something JSON.stringify can serialize losslessly
## enough for an LLM to read (math types become var_to_str strings).
static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_OBJECT:
			if value == null:
				return null
			var res := value as Resource
			if res != null and res.resource_path != "":
				return res.resource_path
			return "<%s>" % (value as Object).get_class()
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[str(key)] = encode(value[key])
			return out
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(encode(item))
			return items
		_:
			return var_to_str(value)
