@tool
extends RefCounted
## WebSocket JSON-RPC server (localhost only). Pure GDScript: TCPServer +
## WebSocketPeer.accept_stream per connection, polled from the plugin's
## _process on the main thread — editor mutations therefore always run on the
## main thread.

const Session := preload("res://addons/ai_console/mcp/jsonrpc_session.gd")

signal client_connected(session)
signal client_disconnected(session)

const PORT_START := 9080
const PORT_END := 9099
const BIND_ADDRESS := "127.0.0.1"

var tcp := TCPServer.new()
var sessions: Array = []
var port := 0
var protocol  # mcp_protocol.gd


## Tries preferred_port first (when > 0), then scans the default range.
## Returns the bound port, or 0 on failure.
func start(preferred_port: int = 0) -> int:
	var candidates: Array[int] = []
	if preferred_port > 0:
		candidates.append(preferred_port)
	for candidate in range(PORT_START, PORT_END + 1):
		if candidate != preferred_port:
			candidates.append(candidate)
	for candidate in candidates:
		if tcp.listen(candidate, BIND_ADDRESS) == OK:
			port = candidate
			return port
	return 0


func poll() -> void:
	if port == 0:
		return
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		if stream == null:
			break
		var session = Session.new()
		session.setup(stream, protocol)
		sessions.append(session)
		client_connected.emit(session)
	for session in sessions.duplicate():
		session.poll()
		if session.closed:
			sessions.erase(session)
			client_disconnected.emit(session)


func stop() -> void:
	for session in sessions:
		session.close()
	sessions.clear()
	if port != 0:
		tcp.stop()
		port = 0
