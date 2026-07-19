@tool
extends "res://addons/ai_console/core/editor_command.gd"

const PolyHaven := preload("res://addons/ai_console/core/asset_sources/polyhaven.gd")
const AmbientCG := preload("res://addons/ai_console/core/asset_sources/ambientcg.gd")

const INDEX_PATH := "res://addons/ai_console/core/asset_sources/asset_index.json"

var _polyhaven = null


func _init() -> void:
	name = "search_assets"
	description = "Search free CC0 game assets across Poly Haven (3D models/materials/HDRIs, auto-downloadable), ambientCG (PBR materials, auto-downloadable) and a curated index (Kenney 2D packs, Quaternius animated characters, Mixamo — download:'manual' means the user downloads from the homepage, then you run import_asset_zip). Follow up with download_asset for auto-downloadable results."
	params_schema = {
		"type": "object",
		"properties": {
			"query": {"type": "string", "description": "Keywords, e.g. 'chair', 'brick wall', 'knight'."},
			"kind": {"type": "string", "enum": ["any", "model", "material", "hdri", "sprite", "tileset", "ui", "audio", "character_animated"], "default": "any"},
			"limit": {"type": "integer", "default": 8, "description": "Max results per source."},
		},
		"required": ["query"],
	}
	undoable = false
	long_running = true


func execute(params: Dictionary, ctx) -> Dictionary:
	var async = ctx.make_async()
	_run(params, ctx, async)
	return {"__pending": async}


func _run(params: Dictionary, ctx, async) -> void:
	var query := String(params["query"])
	var kind := String(params["kind"])
	var limit := clampi(int(params["limit"]), 1, 25)
	var downloader: Node = ctx.plugin.downloader
	var entries := _search_index(query, kind)
	var errors := []

	if kind in ["any", "model", "material", "hdri"]:
		if _polyhaven == null:
			_polyhaven = PolyHaven.new()
		var ph_kinds := ["model", "material", "hdri"] if kind == "any" else [kind]
		for ph_kind in ph_kinds:
			var ph_result: Dictionary = await _polyhaven.search(downloader, query, ph_kind, limit).resolved
			if ph_result.get("ok", false):
				entries.append_array(ph_result["result"]["entries"])
			else:
				errors.append("polyhaven: " + String(ph_result["error"]["message"]))

	if kind in ["any", "material"]:
		var acg_result: Dictionary = await AmbientCG.new().search(downloader, query, limit).resolved
		if acg_result.get("ok", false):
			entries.append_array(acg_result["result"]["entries"])
		else:
			errors.append("ambientcg: " + String(acg_result["error"]["message"]))

	var result := {
		"entries": entries,
		"note": "All CC0 unless stated. Auto-download entries with download_asset; download:'manual' entries: send the user the homepage link, they download the zip, then call import_asset_zip with the local file path.",
	}
	if not errors.is_empty():
		result["source_errors"] = errors
	async.resolve(R.ok(result))


func _search_index(query: String, kind: String) -> Array:
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return []
	var needle := query.to_lower()
	var out := []
	for entry in data.get("entries", []):
		if kind != "any" and String(entry.get("kind", "")) != kind:
			continue
		var haystack := (String(entry.get("name", "")) + " " + String(entry.get("note", ""))).to_lower()
		for tag in entry.get("tags", []):
			haystack += " " + String(tag).to_lower()
		if needle == "" or haystack.contains(needle) or needle.contains(String(entry.get("kind", "-"))):
			out.append(entry)
	return out
