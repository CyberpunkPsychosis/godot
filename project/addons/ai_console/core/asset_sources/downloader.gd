@tool
extends Node
## Async HTTP downloader + safe zip extraction for the asset pipeline.
## Lives as a child of the plugin (HTTPRequest needs the tree). All public
## calls return an AsyncResult that resolves with the usual ok/err envelope.

const R := preload("res://addons/ai_console/core/command_result.gd")
const AsyncResult := preload("res://addons/ai_console/core/async_result.gd")

const MAX_DOWNLOAD_BYTES := 200 * 1024 * 1024
const REQUEST_TIMEOUT := 180.0


## Downloads one URL to an absolute file path. Resolves {ok, result:{path, bytes}}.
func fetch(url: String, dest_path: String) -> RefCounted:
	var async := AsyncResult.new()
	_fetch_into(url, dest_path, async)
	return async


func _fetch_into(url: String, dest_path: String, async: RefCounted) -> void:
	DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
	var request := HTTPRequest.new()
	request.download_file = dest_path
	request.timeout = REQUEST_TIMEOUT
	request.body_size_limit = MAX_DOWNLOAD_BYTES
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			async.resolve(R.err("DOWNLOAD_FAILED", "Download failed (HTTPRequest result %d) for %s" % [result, url]))
		elif code >= 400:
			async.resolve(R.err("DOWNLOAD_FAILED", "Server returned HTTP %d for %s" % [code, url]))
		else:
			var size := 0
			if FileAccess.file_exists(dest_path):
				var f := FileAccess.open(dest_path, FileAccess.READ)
				size = f.get_length()
				f.close()
			async.resolve(R.ok({"path": dest_path, "bytes": size}))
	)
	var err := request.request(url)
	if err != OK:
		request.queue_free()
		async.resolve(R.err("DOWNLOAD_FAILED", "Could not start request (error %d) for %s" % [err, url]))


## Downloads a list of {url, path} sequentially. Resolves after the last one;
## fails fast on the first error.
func fetch_all(items: Array) -> RefCounted:
	var async := AsyncResult.new()
	_fetch_all_from(items, 0, [], async)
	return async


func _fetch_all_from(items: Array, index: int, done: Array, async: RefCounted) -> void:
	if index >= items.size():
		async.resolve(R.ok({"files": done}))
		return
	var item: Dictionary = items[index]
	var single := fetch(String(item["url"]), String(item["path"]))
	single.resolved.connect(func(res: Dictionary) -> void:
		if not res.get("ok", false):
			async.resolve(res)
			return
		done.append(res["result"]["path"])
		_fetch_all_from(items, index + 1, done, async)
	)


## Fetches a URL and parses the body as JSON (for API queries).
## Resolves {ok, result:{data}}.
func fetch_json(url: String) -> RefCounted:
	var async := AsyncResult.new()
	var request := HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = 32 * 1024 * 1024
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
			async.resolve(R.err("API_FAILED", "Request failed (result %d, HTTP %d) for %s" % [result, code, url]))
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if data == null:
			async.resolve(R.err("API_FAILED", "Response was not valid JSON: " + url))
			return
		async.resolve(R.ok({"data": data}))
	)
	var err := request.request(url, ["Accept: application/json", "User-Agent: godot-ai-console/0.1"])
	if err != OK:
		request.queue_free()
		async.resolve(R.err("API_FAILED", "Could not start request (error %d) for %s" % [err, url]))
	return async


## Extracts a zip into dest_dir (absolute), rejecting unsafe entry paths.
## Returns {ok, result:{files}} synchronously (ZIPReader is fast enough).
static func extract_zip(zip_path: String, dest_dir: String) -> Dictionary:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return R.err("ZIP_INVALID", "Could not open zip (error %d): %s" % [err, zip_path])
	var written: Array[String] = []
	for entry in reader.get_files():
		var entry_name := String(entry)
		if entry_name.ends_with("/"):
			continue
		if entry_name.begins_with("/") or entry_name.contains("..") or entry_name.contains(":"):
			reader.close()
			return R.err("ZIP_UNSAFE", "Zip contains an unsafe path ('%s'); extraction aborted." % entry_name)
		var target := dest_dir.path_join(entry_name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			reader.close()
			return R.err("WRITE_FAILED", "Could not write " + target)
		out.store_buffer(reader.read_file(entry))
		out.close()
		written.append(target)
	reader.close()
	return R.ok({"files": written})


## Writes the provenance/license note every downloaded pack gets.
static func write_license_note(dest_dir: String, source_name: String, source_url: String, license_name: String) -> void:
	var out := FileAccess.open(dest_dir.path_join("LICENSE.txt"), FileAccess.WRITE)
	if out != null:
		out.store_string("Source: %s\nURL: %s\nLicense: %s\nDownloaded via Godot AI Console.\n" % [source_name, source_url, license_name])
		out.close()


## Rescans the project filesystem and resolves once the scan settles (or after
## a timeout — imports of large packs may continue in the background).
func rescan_and_wait(timeout_seconds: float = 15.0) -> RefCounted:
	var async := AsyncResult.new()
	var efs := EditorInterface.get_resource_filesystem()
	var handler := func() -> void:
		async.resolve(R.ok({"scanned": true}))
	efs.filesystem_changed.connect(handler, CONNECT_ONE_SHOT)
	efs.scan()
	get_tree().create_timer(timeout_seconds).timeout.connect(func() -> void:
		if efs.filesystem_changed.is_connected(handler):
			efs.filesystem_changed.disconnect(handler)
		async.resolve(R.ok({"scanned": false, "note": "Scan still running; imported assets may appear shortly."}))
	)
	return async
