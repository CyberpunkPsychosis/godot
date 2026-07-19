@tool
extends RefCounted
## ambientCG API adapter (https://ambientcg.com) — CC0 PBR materials.
## Search hits the live API with the query; downloads are single zips
## (e.g. Bricks097_1K-JPG.zip) containing Color/NormalGL/Roughness maps.

const R := preload("res://addons/ai_console/core/command_result.gd")
const AsyncResult := preload("res://addons/ai_console/core/async_result.gd")

const API := "https://ambientcg.com/api/v2/full_json"


func search(downloader: Node, query: String, limit: int) -> RefCounted:
	var async := AsyncResult.new()
	var url := "%s?type=Material&limit=%d&include=downloadData&q=%s" % [API, limit, query.uri_encode()]
	var fetching = downloader.fetch_json(url)
	fetching.resolved.connect(func(res: Dictionary) -> void:
		if not res.get("ok", false):
			async.resolve(res)
			return
		var entries := []
		for asset in res["result"]["data"].get("foundAssets", []):
			var link := _zip_link(asset, "1K-JPG")
			if link == "":
				continue
			entries.append({
				"source": "ambientcg",
				"id": String(asset.get("assetId", "")),
				"name": String(asset.get("assetId", "")),
				"kind": "material",
				"license": "CC0",
				"tags": asset.get("tags", []),
				"download_url": link,
			})
		async.resolve(R.ok({"entries": entries}))
	)
	return async


static func _zip_link(asset: Dictionary, attribute: String) -> String:
	var downloads: Array = asset.get("downloadFolders", {}).get("default", {}) \
		.get("downloadFiletypeCategories", {}).get("zip", {}).get("downloads", [])
	for download in downloads:
		if String(download.get("attribute", "")) == attribute:
			return String(download.get("downloadLink", ""))
	if not downloads.is_empty():
		return String(downloads[0].get("downloadLink", ""))
	return ""


static func direct_url(asset_id: String, attribute: String = "1K-JPG") -> String:
	return "https://ambientcg.com/get?file=%s_%s.zip" % [asset_id, attribute]
