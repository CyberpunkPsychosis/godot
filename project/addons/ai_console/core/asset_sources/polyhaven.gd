@tool
extends RefCounted
## Poly Haven API adapter (https://api.polyhaven.com) — CC0 3D models,
## PBR textures and HDRIs. The asset list is fetched once per kind and cached
## for the session; search filters client-side over slug/name/tags/categories.

const R := preload("res://addons/ai_console/core/command_result.gd")
const AsyncResult := preload("res://addons/ai_console/core/async_result.gd")

const API_BASE := "https://api.polyhaven.com"
const KIND_TO_TYPE := {"model": "models", "material": "textures", "hdri": "hdris"}

var _cache: Dictionary = {}  # kind -> Dictionary of slug -> info


func search(downloader: Node, query: String, kind: String, limit: int) -> RefCounted:
	var async := AsyncResult.new()
	if not KIND_TO_TYPE.has(kind):
		async.resolve(R.ok({"entries": []}))
		return async
	if _cache.has(kind):
		async.resolve(R.ok({"entries": _filter(_cache[kind], query, kind, limit)}))
		return async
	var fetching = downloader.fetch_json("%s/assets?type=%s" % [API_BASE, KIND_TO_TYPE[kind]])
	fetching.resolved.connect(func(res: Dictionary) -> void:
		if not res.get("ok", false):
			async.resolve(res)
			return
		_cache[kind] = res["result"]["data"]
		async.resolve(R.ok({"entries": _filter(_cache[kind], query, kind, limit)}))
	)
	return async


func _filter(assets: Dictionary, query: String, kind: String, limit: int) -> Array:
	var needle := query.to_lower()
	var entries := []
	for slug in assets:
		var info: Dictionary = assets[slug]
		var haystack := (String(slug) + " " + String(info.get("name", ""))).to_lower()
		for tag in info.get("tags", []):
			haystack += " " + String(tag).to_lower()
		for category in info.get("categories", []):
			haystack += " " + String(category).to_lower()
		if needle != "" and not haystack.contains(needle):
			continue
		entries.append({
			"source": "polyhaven",
			"id": String(slug),
			"name": String(info.get("name", slug)),
			"kind": kind,
			"license": "CC0",
			"tags": info.get("tags", []),
		})
		if entries.size() >= limit:
			break
	return entries


## Resolves the file list needed to download a model/texture/hdri:
## {files: [{url, relpath}], license, homepage}. Models use glTF + its
## `include` map (bin + textures) so relative paths keep working after save.
func resolve_download(downloader: Node, slug: String, kind: String, resolution: String) -> RefCounted:
	var async := AsyncResult.new()
	var fetching = downloader.fetch_json("%s/files/%s" % [API_BASE, slug])
	fetching.resolved.connect(func(res: Dictionary) -> void:
		if not res.get("ok", false):
			async.resolve(res)
			return
		var data: Dictionary = res["result"]["data"]
		var files := []
		match kind:
			"model":
				var gltf_levels: Dictionary = data.get("gltf", {})
				var level: Dictionary = gltf_levels.get(resolution, {})
				if level.is_empty() and not gltf_levels.is_empty():
					level = gltf_levels[gltf_levels.keys()[0]]
				var gltf: Dictionary = level.get("gltf", {})
				if gltf.is_empty():
					async.resolve(R.err("NO_GLTF", "Poly Haven asset '%s' has no glTF download." % slug))
					return
				files.append({"url": String(gltf["url"]), "relpath": String(gltf["url"]).get_file()})
				var includes: Dictionary = gltf.get("include", {})
				for relpath in includes:
					files.append({"url": String(includes[relpath]["url"]), "relpath": String(relpath)})
			"hdri":
				var hdri_levels: Dictionary = data.get("hdri", {})
				var hdri_level: Dictionary = hdri_levels.get(resolution, hdri_levels.get("1k", {}))
				if hdri_level.has("hdr"):
					files.append({"url": String(hdri_level["hdr"]["url"]), "relpath": String(hdri_level["hdr"]["url"]).get_file()})
			"material":
				# Grab the common PBR maps in jpg at the chosen resolution.
				for map_name in ["Diffuse", "diff", "nor_gl", "Rough", "rough", "arm", "AO"]:
					var maps: Dictionary = data.get(map_name, {})
					var level2: Dictionary = maps.get(resolution, {})
					var jpg: Dictionary = level2.get("jpg", {})
					if jpg.has("url"):
						files.append({"url": String(jpg["url"]), "relpath": String(jpg["url"]).get_file()})
		if files.is_empty():
			async.resolve(R.err("NO_FILES", "No downloadable files resolved for '%s' (%s, %s)." % [slug, kind, resolution]))
			return
		async.resolve(R.ok({
			"files": files,
			"license": "CC0",
			"homepage": "https://polyhaven.com/a/" + slug,
		}))
	)
	return async
