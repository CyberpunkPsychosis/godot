@tool
extends RefCounted
## One WebSocket client connection speaking JSON-RPC 2.0 / MCP.
## Created by ws_server for each accepted TCP stream; polled every frame.

var ws := WebSocketPeer.new()
var protocol  # mcp_protocol.gd
var closed := false
var mcp_initialized := false
var client_info: Dictionary = {}

const MAX_FRAME_BYTES := 2 * 1024 * 1024


func setup(stream: StreamPeerTCP, proto) -> void:
	protocol = proto
	ws.inbound_buffer_size = 4 * 1024 * 1024
	ws.outbound_buffer_size = 8 * 1024 * 1024
	ws.max_queued_packets = 1024
	ws.accept_stream(stream)


func poll() -> void:
	if closed:
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			if packet.size() > MAX_FRAME_BYTES:
				send_error(null, -32600, "Frame too large (limit %d bytes)." % MAX_FRAME_BYTES)
				continue
			_handle_text(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		closed = true


func _handle_text(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if msg == null or typeof(msg) != TYPE_DICTIONARY:
		send_error(null, -32700, "Parse error: expected a JSON-RPC 2.0 object.")
		return
	protocol.handle(self, msg)


func send(msg: Dictionary) -> void:
	if not closed and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func send_result(id: Variant, result: Dictionary) -> void:
	send({"jsonrpc": "2.0", "id": id, "result": result})


func send_error(id: Variant, code: int, message: String) -> void:
	send({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})


func close() -> void:
	if not closed:
		ws.close()
	closed = true
