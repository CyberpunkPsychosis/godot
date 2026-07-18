@tool
extends RefCounted
## Chat/LLM settings stored per-project in the EDITOR layer (project metadata),
## so API keys never end up in project.godot or version control.
## Env vars ANTHROPIC_API_KEY / OPENAI_API_KEY are used as fallback when no key
## is stored, letting users avoid on-disk storage entirely.

const SECTION := "ai_console"

const DEFAULTS := {
	"provider": "anthropic",  # "anthropic" | "openai_compat"
	"api_key": "",
	"base_url": "",  # empty = provider default
	"model": "claude-sonnet-4-5",
	"max_tokens": 4096,
	"mcp_enabled": true,
	"mcp_port": 0,  # 0 = auto (scan 9080-9099)
}


static func get_all() -> Dictionary:
	var settings := EditorInterface.get_editor_settings()
	var out := {}
	for key in DEFAULTS:
		out[key] = settings.get_project_metadata(SECTION, key, DEFAULTS[key])
	if String(out["api_key"]) == "":
		if String(out["provider"]) == "anthropic":
			out["api_key"] = OS.get_environment("ANTHROPIC_API_KEY")
		else:
			out["api_key"] = OS.get_environment("OPENAI_API_KEY")
	if String(out["base_url"]) == "":
		if String(out["provider"]) == "anthropic":
			out["base_url"] = "https://api.anthropic.com"
		else:
			out["base_url"] = "https://api.openai.com/v1"
	return out


static func set_value(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(SECTION, key, value)


static func get_stored(key: String) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(SECTION, key, DEFAULTS.get(key))
