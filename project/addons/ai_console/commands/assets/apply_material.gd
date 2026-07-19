@tool
extends "res://addons/ai_console/core/editor_command.gd"


func _init() -> void:
	name = "apply_material"
	description = "Build a StandardMaterial3D from a downloaded PBR texture folder (ambientCG/Poly Haven naming: *Color*/*diff* albedo, *NormalGL*/*nor_gl* normal, *Roughness*/*rough* roughness) and assign it to a MeshInstance3D as material_override. Saves the material as .tres next to the textures. Undoable."
	params_schema = {
		"type": "object",
		"properties": {
			"path": {"type": "string", "description": "MeshInstance3D node path in the scene."},
			"material_dir": {"type": "string", "description": "e.g. res://assets/bricks097"},
			"uv_scale": {"type": "number", "default": 1.0, "description": "Tiling factor."},
		},
		"required": ["path", "material_dir"],
	}


func execute(params: Dictionary, ctx) -> Dictionary:
	var resolved: Dictionary = ctx.resolve_node(String(params["path"]))
	if not resolved.get("ok", false):
		return resolved
	var node: Node = resolved["node"]
	var mesh_instance := node as GeometryInstance3D
	if mesh_instance == null:
		return R.err("NOT_A_MESH", "Node '%s' (%s) is not a MeshInstance3D/GeometryInstance3D." % [node.name, node.get_class()])
	var dir_path := String(params["material_dir"]).trim_suffix("/")
	var maps := _find_maps(dir_path)
	if not maps.has("albedo"):
		return R.err("NO_TEXTURES",
			"No albedo/Color texture found in %s. Files present: %s" % [dir_path, str(_list_textures(dir_path))])
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(maps["albedo"])
	if maps.has("normal"):
		material.normal_enabled = true
		material.normal_texture = load(maps["normal"])
	if maps.has("roughness"):
		material.roughness_texture = load(maps["roughness"])
	var scale := float(params["uv_scale"])
	if scale != 1.0:
		material.uv1_scale = Vector3(scale, scale, scale)
	var material_path := dir_path.path_join("material.tres")
	var save_err := ResourceSaver.save(material, material_path)
	if save_err != OK:
		return R.err("SAVE_FAILED", "Could not save material (error %d)." % save_err)
	EditorInterface.get_resource_filesystem().update_file(material_path)
	var saved_material := load(material_path)
	var old_value: Variant = mesh_instance.material_override
	ctx.ops.set_prop(mesh_instance, "material_override", saved_material)
	ctx.begin_action("AI: apply_material")
	ctx.record_property(mesh_instance, "material_override", old_value, saved_material)
	ctx.end_action()
	return R.ok({
		"node": ctx.summarize_node(node),
		"material": material_path,
		"maps": maps,
	})


func _find_maps(dir_path: String) -> Dictionary:
	var maps := {}
	for file_name in _list_textures(dir_path):
		var lower := file_name.to_lower()
		var full := dir_path.path_join(file_name)
		if not maps.has("albedo") and (lower.contains("color") or lower.contains("diff") or lower.contains("albedo")):
			maps["albedo"] = full
		elif not maps.has("normal") and (lower.contains("normalgl") or lower.contains("nor_gl") or lower.contains("normal")):
			maps["normal"] = full
		elif not maps.has("roughness") and lower.contains("rough"):
			maps["roughness"] = full
	return maps


func _list_textures(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "exr"]:
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
