extends SceneTree
## Headless test for the downloader's zip extraction safety: a zip containing
## path-traversal entries must be rejected wholesale, a clean zip must extract.
## CI creates the fixture zips (see scripts/ci_validate.sh) and passes their
## directory via the AI_ZIP_FIXTURES env var.

const Downloader := preload("res://addons/ai_console/core/asset_sources/downloader.gd")


func _initialize() -> void:
	var fixtures := OS.get_environment("AI_ZIP_FIXTURES")
	if fixtures == "":
		print("zip safety check: SKIP (AI_ZIP_FIXTURES not set)")
		quit(0)
		return
	var failures := 0
	var dest := fixtures.path_join("out")

	var evil: Dictionary = Downloader.extract_zip(fixtures.path_join("evil.zip"), dest)
	if evil.get("ok", false) or String(evil.get("error", {}).get("code", "")) != "ZIP_UNSAFE":
		push_error("evil.zip was NOT rejected: " + JSON.stringify(evil))
		failures += 1
	if FileAccess.file_exists(fixtures.path_join("escaped.txt")):
		push_error("path traversal escaped the destination directory!")
		failures += 1

	var clean: Dictionary = Downloader.extract_zip(fixtures.path_join("clean.zip"), dest)
	if not clean.get("ok", false):
		push_error("clean.zip failed to extract: " + JSON.stringify(clean))
		failures += 1
	elif not FileAccess.file_exists(dest.path_join("sub/hello.txt")):
		push_error("clean.zip extraction missing expected file")
		failures += 1

	print("zip safety check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
