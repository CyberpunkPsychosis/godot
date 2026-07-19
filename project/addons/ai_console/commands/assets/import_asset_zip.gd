@tool
extends "res://addons/ai_console/core/editor_command.gd"

const Downloader := preload("res://addons/ai_console/core/asset_sources/downloader.gd")


func _init() -> void:
	name = "import_asset_zip"
	description = "Import a zip the user downloaded manually (Kenney, Quaternius, Mixamo exports, itch.io packs...) into res://assets/<name>/. Give the absolute path of the downloaded zip (e.g. C:/Users/me/Downloads/kenney_pixel-platformer.zip). Unsafe zip entries are rejected. After import, textures/sprites/models are ready for the other commands."
	params_schema = {
		"type": "object",
		"properties": {
			"zip_path": {"type": "string", "description": "Absolute path to the downloaded .zip on this machine."},
			"name": {"type": "string", "description": "Folder name under res://assets/ (defaults to the zip filename)."},
		},
		"required": ["zip_path"],
	}
	undoable = false
	long_running = true


func execute(params: Dictionary, ctx) -> Dictionary:
	var async = ctx.make_async()
	_run(params, ctx, async)
	return {"__pending": async}


func _run(params: Dictionary, ctx, async) -> void:
	var zip_path := String(params["zip_path"]).strip_edges().trim_prefix("\"").trim_suffix("\"")
	if zip_path.begins_with("user://"):
		zip_path = ProjectSettings.globalize_path(zip_path)
	if not FileAccess.file_exists(zip_path):
		async.resolve(R.err("FILE_NOT_FOUND",
			"No file at '%s'. Ask the user for the exact path of the downloaded zip (often in the Downloads folder)." % zip_path))
		return
	var folder_name := String(params.get("name", ""))
	if folder_name == "":
		folder_name = zip_path.get_file().get_basename().to_snake_case()
	var dest_dir := ProjectSettings.globalize_path("res://assets/" + folder_name)
	var extracted: Dictionary = Downloader.extract_zip(zip_path, dest_dir)
	if not extracted.get("ok", false):
		async.resolve(extracted)
		return
	Downloader.write_license_note(dest_dir, "manual import", zip_path, "see source page")
	await ctx.plugin.downloader.rescan_and_wait().resolved
	var files := []
	for file_path in extracted["result"]["files"]:
		files.append("res://assets/" + folder_name + "/" + String(file_path).trim_prefix(dest_dir).trim_prefix("/"))
		if files.size() >= 200:
			break
	async.resolve(R.ok({"dir": "res://assets/" + folder_name, "files": files}))
