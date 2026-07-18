@tool
extends RefCounted
## Streaming HTTP client for SSE-based LLM APIs.
## HTTPRequest buffers whole bodies, so this uses HTTPClient polled per frame
## from the dock. SSE blocks are split on byte boundaries (\n\n) BEFORE UTF-8
## decoding, so multi-byte characters split across TCP chunks can't corrupt
## the stream.

signal sse_event(data: Dictionary)
signal finished(error_message: String)  # "" on success

var active := false

var _http: HTTPClient
var _host := ""
var _port := 443
var _use_tls := true
var _path := "/"
var _headers := PackedStringArray()
var _body := ""
var _requested := false
var _raw := PackedByteArray()
var _response_code := 0
var _error_body := ""
var _finished_emitted := false


func start(url: String, headers: Dictionary, body: Dictionary) -> void:
	var parsed := _parse_url(url)
	if parsed.is_empty():
		_finish("Invalid URL: " + url)
		return
	_host = parsed["host"]
	_port = parsed["port"]
	_use_tls = parsed["tls"]
	_path = parsed["path"]
	_headers = PackedStringArray()
	for key in headers:
		_headers.append("%s: %s" % [key, headers[key]])
	_headers.append("Content-Type: application/json")
	_headers.append("Accept: text/event-stream")
	_body = JSON.stringify(body)
	_raw = PackedByteArray()
	_requested = false
	_response_code = 0
	_error_body = ""
	_finished_emitted = false
	_http = HTTPClient.new()
	_http.read_chunk_size = 16384
	var tls: TLSOptions = TLSOptions.client() if _use_tls else null
	var err := _http.connect_to_host(_host, _port, tls)
	if err != OK:
		_finish("Could not connect to %s (error %d)." % [_host, err])
		return
	active = true


func abort() -> void:
	if _http != null:
		_http.close()
	_finish("aborted")


func poll() -> void:
	if not active:
		return
	_http.poll()
	var status := _http.get_status()
	match status:
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			pass
		HTTPClient.STATUS_CONNECTED:
			if not _requested:
				var err := _http.request(HTTPClient.METHOD_POST, _path, _headers, _body)
				if err != OK:
					_finish("Request failed (error %d)." % err)
					return
				_requested = true
			else:
				_on_body_complete()
		HTTPClient.STATUS_BODY:
			if _response_code == 0:
				_response_code = _http.get_response_code()
			var chunk := _http.read_response_body_chunk()
			if chunk.size() > 0:
				if _response_code >= 400:
					_error_body += chunk.get_string_from_utf8()
				else:
					_raw.append_array(chunk)
					_drain_events()
		HTTPClient.STATUS_DISCONNECTED:
			_on_body_complete()
		_:
			_finish("Connection error (HTTPClient status %d). Check base URL, network and proxy." % status)


func _on_body_complete() -> void:
	if _response_code >= 400:
		_finish("API returned HTTP %d: %s" % [_response_code, _error_body.left(600)])
	else:
		_drain_events()
		_finish("")


func _drain_events() -> void:
	while true:
		var boundary := _find_block_end()
		if boundary.is_empty():
			return
		var block: PackedByteArray = _raw.slice(0, boundary["end"])
		_raw = _raw.slice(boundary["end"] + boundary["sep"])
		_handle_block(block.get_string_from_utf8())


## Finds the first \n\n or \r\n\r\n separator in the raw byte buffer.
func _find_block_end() -> Dictionary:
	var size := _raw.size()
	for i in range(size - 1):
		if _raw[i] == 10 and _raw[i + 1] == 10:
			return {"end": i, "sep": 2}
		if i + 3 < size and _raw[i] == 13 and _raw[i + 1] == 10 and _raw[i + 2] == 13 and _raw[i + 3] == 10:
			return {"end": i, "sep": 4}
	return {}


func _handle_block(block: String) -> void:
	for line in block.split("\n"):
		line = line.strip_edges()
		if not line.begins_with("data:"):
			continue
		var payload := line.substr(5).strip_edges()
		if payload == "[DONE]":
			_finish("")
			return
		var data: Variant = JSON.parse_string(payload)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			sse_event.emit(data)


func _finish(error_message: String) -> void:
	active = false
	if _finished_emitted:
		return
	_finished_emitted = true
	finished.emit(error_message)


func _parse_url(url: String) -> Dictionary:
	var tls := true
	var rest := url
	if url.begins_with("https://"):
		rest = url.substr(8)
	elif url.begins_with("http://"):
		tls = false
		rest = url.substr(7)
	else:
		return {}
	var slash := rest.find("/")
	var host_port := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var host := host_port
	var port := 443 if tls else 80
	var colon := host_port.find(":")
	if colon >= 0:
		host = host_port.substr(0, colon)
		port = int(host_port.substr(colon + 1))
	if host == "":
		return {}
	return {"host": host, "port": port, "tls": tls, "path": path}
