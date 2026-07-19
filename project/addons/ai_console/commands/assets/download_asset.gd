@tool
extends "res://addons/ai_console/core/editor_command.gd"

const PolyHaven := preload("res://addons/ai_console/core/asset_sources/polyhaven.gd")
const AmbientCG := preload("res://addons/ai_console/core/asset_sources/ambientcg.gd")
const Downloader := preload("res://addons/ai_console/core/asset_sources/downloader.gd")


func _init() -> void:
	name = "download_asset"
	description = "Download a CC0 asset found via search_assets into res://assets/<name>/ and import it. source 'polyhaven' + id downloads models (glTF + textures), materials or HDRIs; source 'ambientcg' + id downloads a PBR material zip; source 'url' downloads any direct file/zip URL. Writes a LICENSE.txt with provenance. After a model download, use add_model_to_scene."
	params_schema = {
		"type": "object",
		"properties": {
			"source": {"type": "string", "enum": ["polyhaven", "ambientcg", "url"]},
			"id": {"type": "string", "description": "Asset id/slug for polyhaven or ambientcg."},
			"kind": {"type": "string", "enum": ["model", "material", "hdri"], "default": "model", "description": "For polyhaven only."},
			"url": {"type": "string", "description": "Direct URL for source=url."},
			"resolution": {"type": "string", "default": "1k", "description": "polyhaven: 1k/2k/4k."},
			"name": {"type": "string", "description": "Folder name under res://assets/ (defaults to the id/filename)."},
		},
		"required": ["source"],
	}
	undoable = false
	long_running = true


func execute(params: Dictionary, ctx) -> Dictionary:
	var async = ctx.make_async()
	_run(params, ctx, async)
	return {"__pending": async}


func _run(params: Dictionary, ctx, async) -> void:
	var source := String(params["source"])
	var downloader: Node = ctx.plugin.downloader
	var asset_id := String(params.get("id", ""))
	var folder_name := String(params.get("name", ""))
	match source:
		"polyhaven":
			if asset_id == "":
				async.resolve(R.err("SCHEMA_INVALID", "source=polyhaven requires 'id'."))
				return
			if folder_name == "":
				folder_name = asset_id.to_snake_case()
			var kind := String(params["kind"])
			var resolved: Dictionary = await PolyHaven.new().resolve_download(downloader, asset_id, kind, String(params["resolution"])).resolved
			if not resolved.get("ok", false):
				async.resolve(resolved)
				return
			var dest_dir := ProjectSettings.globalize_path("res://assets/" + folder_name)
			var items := []
			for file_info in resolved["result"]["files"]:
				items.append({"url": file_info["url"], "path": dest_dir.path_join(String(file_info["relpath"]))})
			var downloaded: Dictionary = await downloader.fetch_all(items).resolved
			if not downloaded.get("ok", false):
				async.resolve(downloaded)
				return
			Downloader.write_license_note(dest_dir, "Poly Haven", String(resolved["result"]["homepage"]), "CC0")
			await downloader.rescan_and_wait().resolved
			async.resolve(R.ok({
				"dir": "res://assets/" + folder_name,
				"files": _project_files(folder_name),
				"license": "CC0",
			}))
		"ambientcg":
			if asset_id == "":
				async.resolve(R.err("SCHEMA_INVALID", "source=ambientcg requires 'id'."))
				return
			if folder_name == "":
				folder_name = asset_id.to_snake_case()
			await _download_zip(ctx, async, AmbientCG.direct_url(asset_id), folder_name,
				"ambientCG", "https://ambientcg.com/view?id=" + asset_id, "CC0")
		"url":
			var url := String(params.get("url", ""))
			if not url.begins_with("http"):
				async.resolve(R.err("SCHEMA_INVALID", "source=url requires a valid 'url'."))
				return
			if folder_name == "":
				folder_name = url.get_file().get_basename().to_snake_case()
			if url.get_extension().to_lower() == "zip":
				await _download_zip(ctx, async, url, folder_name, url, url, "see source page")
			else:
				var dest := ProjectSettings.globalize_path("res://assets/%s/%s" % [folder_name, url.get_file()])
				var fetched: Dictionary = await downloader.fetch(url, dest).resolved
				if not fetched.get("ok", false):
					async.resolve(fetched)
					return
				await downloader.rescan_and_wait().resolved
				async.resolve(R.ok({"dir": "res://assets/" + folder_name, "files": _project_files(folder_name)}))


func _download_zip(ctx, async, url: String, folder_name: String, source_name: String, homepage: String, license_name: String) -> void:
	var downloader: Node = ctx.plugin.downloader
	var tmp_zip := ProjectSettings.globalize_path("user://ai_console/tmp/%s.zip" % folder_name)
	var fetched: Dictionary = await downloader.fetch(url, tmp_zip).resolved
	if not fetched.get("ok", false):
		async.resolve(fetched)
		return
	var dest_dir := ProjectSettings.globalize_path("res://assets/" + folder_name)
	var extracted: Dictionary = Downloader.extract_zip(tmp_zip, dest_dir)
	DirAccess.remove_absolute(tmp_zip)
	if not extracted.get("ok", false):
		async.resolve(extracted)
		return
	Downloader.write_license_note(dest_dir, source_name, homepage, license_name)
	await downloader.rescan_and_wait().resolved
	async.resolve(R.ok({
		"dir": "res://assets/" + folder_name,
		"files": _project_files(folder_name),
		"license": license_name,
	}))


func _project_files(folder_name: String) -> Array:
	var out := []
	_walk("res://assets/" + folder_name, out)
	return out


func _walk(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and out.size() < 200:
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_walk(full, out)
		elif not entry.ends_with(".import"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
