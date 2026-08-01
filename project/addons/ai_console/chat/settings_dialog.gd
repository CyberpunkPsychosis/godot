@tool
extends AcceptDialog
## Settings dialog for the AI Console: provider, API key, base URL, model,
## MCP server toggle/port. Values persist in editor-layer project metadata
## (never committed to the project).

const ChatSettings := preload("res://addons/ai_console/chat/chat_settings.gd")

signal settings_saved

## Quick-fill presets. Anthropic/OpenAI are NOT directly reachable from
## mainland China — DeepSeek/Kimi/GLM/Qwen (all OpenAI-compatible, all support
## tool calls) or a local Ollama are the recommended choices there.
const PRESETS := [
	{"label": "— 选择预设 (presets) —"},
	{"label": "DeepSeek (国内直连推荐)", "provider": "openai_compat", "base_url": "https://api.deepseek.com", "model": "deepseek-chat"},
	{"label": "Kimi / Moonshot (国内直连)", "provider": "openai_compat", "base_url": "https://api.moonshot.cn/v1", "model": "moonshot-v1-8k"},
	{"label": "智谱 GLM (国内直连)", "provider": "openai_compat", "base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4-plus"},
	{"label": "通义千问 Qwen (国内直连)", "provider": "openai_compat", "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus"},
	{"label": "Ollama (本地免费, 需先安装)", "provider": "openai_compat", "base_url": "http://127.0.0.1:11434/v1", "model": "qwen2.5:14b"},
	{"label": "Anthropic Claude (需国际网络)", "provider": "anthropic", "base_url": "https://api.anthropic.com", "model": "claude-sonnet-4-5"},
	{"label": "OpenAI (需国际网络)", "provider": "openai_compat", "base_url": "https://api.openai.com/v1", "model": "gpt-4o"},
]

var _preset: OptionButton
var _provider: OptionButton
var _api_key: LineEdit
var _base_url: LineEdit
var _model: LineEdit
var _max_tokens: SpinBox
var _mcp_enabled: CheckBox
var _mcp_port: SpinBox


func _init() -> void:
	title = "AI Console Settings"
	min_size = Vector2i(460, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)

	grid.add_child(_label("Preset"))
	_preset = OptionButton.new()
	for i in range(PRESETS.size()):
		_preset.add_item(String(PRESETS[i]["label"]), i)
	_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset.item_selected.connect(_on_preset_selected)
	grid.add_child(_preset)

	grid.add_child(_label("Provider"))
	_provider = OptionButton.new()
	_provider.add_item("Anthropic (Claude)", 0)
	_provider.add_item("OpenAI-compatible (OpenAI / DeepSeek / Ollama / ...)", 1)
	_provider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_provider)

	grid.add_child(_label("API key"))
	_api_key = LineEdit.new()
	_api_key.secret = true
	_api_key.placeholder_text = "empty = use ANTHROPIC_API_KEY / OPENAI_API_KEY env var"
	_api_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_api_key)

	grid.add_child(_label("Base URL"))
	_base_url = LineEdit.new()
	_base_url.placeholder_text = "empty = provider default"
	_base_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_base_url)

	grid.add_child(_label("Model"))
	_model = LineEdit.new()
	_model.placeholder_text = "e.g. claude-sonnet-4-5 or gpt-4o"
	_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_model)

	grid.add_child(_label("Max tokens"))
	_max_tokens = SpinBox.new()
	_max_tokens.min_value = 256
	_max_tokens.max_value = 64000
	_max_tokens.step = 256
	grid.add_child(_max_tokens)

	grid.add_child(_label("MCP server"))
	_mcp_enabled = CheckBox.new()
	_mcp_enabled.text = "Enabled (lets Claude Code / Cursor / Cline control this editor)"
	grid.add_child(_mcp_enabled)

	grid.add_child(_label("MCP port"))
	_mcp_port = SpinBox.new()
	_mcp_port.min_value = 0
	_mcp_port.max_value = 65535
	_mcp_port.tooltip_text = "0 = automatic (9080-9099). Changes apply after re-enabling the plugin."
	grid.add_child(_mcp_port)

	add_child(grid)
	confirmed.connect(_save)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_preset_selected(index: int) -> void:
	if index <= 0 or index >= PRESETS.size():
		return
	var preset: Dictionary = PRESETS[index]
	_provider.select(0 if String(preset["provider"]) == "anthropic" else 1)
	_base_url.text = String(preset["base_url"])
	_model.text = String(preset["model"])


func open() -> void:
	_provider.select(0 if String(ChatSettings.get_stored("provider")) == "anthropic" else 1)
	_api_key.text = String(ChatSettings.get_stored("api_key"))
	_base_url.text = String(ChatSettings.get_stored("base_url"))
	_model.text = String(ChatSettings.get_stored("model"))
	_max_tokens.value = int(ChatSettings.get_stored("max_tokens"))
	_mcp_enabled.button_pressed = bool(ChatSettings.get_stored("mcp_enabled"))
	_mcp_port.value = int(ChatSettings.get_stored("mcp_port"))
	popup_centered()


func _save() -> void:
	ChatSettings.set_value("provider", "anthropic" if _provider.selected == 0 else "openai_compat")
	ChatSettings.set_value("api_key", _api_key.text.strip_edges())
	ChatSettings.set_value("base_url", _base_url.text.strip_edges())
	ChatSettings.set_value("model", _model.text.strip_edges())
	ChatSettings.set_value("max_tokens", int(_max_tokens.value))
	ChatSettings.set_value("mcp_enabled", _mcp_enabled.button_pressed)
	ChatSettings.set_value("mcp_port", int(_mcp_port.value))
	settings_saved.emit()
