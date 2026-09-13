class_name GameDebugServer
extends Node
## Optional local HTTP adapter. Command callbacks run on the main thread.

const AtomicJSON = preload("res://scripts/services/atomic_json.gd")
const MAX_HEADER_BYTES: int = 16_384
const MAX_BODY_BYTES: int = 16 * 1024 * 1024
const MAX_CONNECTIONS: int = 16
const REQUEST_TIMEOUT_MSEC: int = 10_000
const ACTIONS: Array[Dictionary] = [
	{"name": "loadLevel", "params": "level: 1-5, or 0 for survival"},
	{"name": "mainMenu", "params": ""},
	{"name": "pause", "params": ""},
	{"name": "resume", "params": ""},
	{"name": "spawnEnemy", "params": "type: grunt|soldier|boss|spawner; x, y: logical world coordinates (y up)"},
	{"name": "killAllEnemies", "params": ""},
	{"name": "healPlayer", "params": ""},
	{"name": "addResources", "params": "amount: positive integer"},
	{"name": "setHermesMode", "params": "mode: following|independent"},
]

var callbacks: Dictionary = {}
var is_running: bool = false
var port: int = 8766
var _server := TCPServer.new()
var _connections: Array[Dictionary] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(handlers: Dictionary) -> void:
	callbacks = handlers


func start_server(listen_port: int = 8766) -> Dictionary:
	if not OS.is_debug_build():
		return AtomicJSON.failure("Debug server is unavailable in release builds")
	if is_running:
		return {"success": true, "port": port}
	if listen_port < 1 or listen_port > 65535:
		return AtomicJSON.failure("Invalid debug port")
	var error := _server.listen(listen_port, "127.0.0.1")
	if error != OK:
		return AtomicJSON.failure("Cannot bind debug server to 127.0.0.1:%d (%s)" % [listen_port, error_string(error)])
	port = listen_port
	is_running = true
	print("Godot debug server: http://127.0.0.1:%d" % port)
	return {"success": true, "port": port}


func stop_server() -> void:
	_server.stop()
	for connection: Dictionary in _connections:
		connection.peer.disconnect_from_host()
	_connections.clear()
	is_running = false


func _exit_tree() -> void:
	stop_server()


func _process(_delta: float) -> void:
	if not is_running:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if _connections.size() >= MAX_CONNECTIONS:
			peer.disconnect_from_host()
		else:
			peer.set_no_delay(true)
			_connections.append({"peer": peer, "buffer": PackedByteArray(), "response": PackedByteArray(), "offset": 0, "started": Time.get_ticks_msec()})
	for index: int in range(_connections.size() - 1, -1, -1):
		var connection: Dictionary = _connections[index]
		var peer: StreamPeerTCP = connection.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - int(connection.started) > REQUEST_TIMEOUT_MSEC:
			peer.disconnect_from_host()
			_connections.remove_at(index)
			continue
		if connection.response.is_empty():
			var available := peer.get_available_bytes()
			if available > 0:
				var received := peer.get_data(mini(available, 65536))
				if received[0] != OK:
					peer.disconnect_from_host()
					_connections.remove_at(index)
					continue
				connection.buffer.append_array(received[1])
				var request := parse_http(connection.buffer)
				if request.get("complete", false):
					var response: Dictionary = route_request(request.method, request.path, request.body) if request.success else _http_error(int(request.status), request.error)
					connection.response = _response_bytes(response)
		if not connection.response.is_empty():
			var remaining: PackedByteArray = connection.response.slice(int(connection.offset))
			var sent := peer.put_partial_data(remaining)
			if sent[0] != OK:
				peer.disconnect_from_host()
				_connections.remove_at(index)
				continue
			connection.offset += int(sent[1])
			if int(connection.offset) >= connection.response.size():
				peer.disconnect_from_host()
				_connections.remove_at(index)


static func parse_http(buffer: PackedByteArray) -> Dictionary:
	var boundary: int = -1
	for index: int in range(maxi(0, buffer.size() - MAX_BODY_BYTES - 4), buffer.size() - 3):
		if buffer[index] == 13 and buffer[index + 1] == 10 and buffer[index + 2] == 13 and buffer[index + 3] == 10:
			boundary = index
			break
	if boundary < 0:
		return _rejected(413, "HTTP headers too large") if buffer.size() > MAX_HEADER_BYTES else {"complete": false}
	if boundary + 4 > MAX_HEADER_BYTES:
		return _rejected(413, "HTTP headers too large")
	var header := buffer.slice(0, boundary).get_string_from_utf8()
	var lines := header.split("\r\n")
	var parts := lines[0].split(" ", true)
	if parts.size() != 3 or not parts[2].begins_with("HTTP/1."):
		return _rejected(400, "Invalid request line")
	var content_length: int = 0
	var has_length: bool = false
	for line: String in lines.slice(1):
		var colon := line.find(":")
		if colon < 1:
			return _rejected(400, "Invalid HTTP header")
		var key := line.left(colon).to_lower()
		var value := line.substr(colon + 1).strip_edges()
		if key == "transfer-encoding":
			return _rejected(400, "Transfer-Encoding is not supported")
		if key == "content-length":
			if has_length or value.is_empty() or not value.is_valid_int() or value.begins_with("-") or value.begins_with("+"):
				return _rejected(400, "Invalid Content-Length")
			if value.length() > 8 or value.to_int() > MAX_BODY_BYTES:
				return _rejected(413, "HTTP body too large")
			content_length = value.to_int()
			has_length = true
	if buffer.size() < boundary + 4 + content_length:
		return {"complete": false}
	return {"complete": true, "success": true, "method": parts[0], "path": parts[1], "body": buffer.slice(boundary + 4, boundary + 4 + content_length)}


func route_request(method: String, path: String, body: PackedByteArray = PackedByteArray()) -> Dictionary:
	if method == "GET" and path == "/health":
		return _ok({"status": "ok", "server": "GameCommandServer", "version": "1.0.0", "engine": "Godot", "coordinates": "state/action positions: logical world, y up; nodes/tap/swipe: viewport pixels, origin top-left"})
	if not _has_callback("state"):
		return _http_error(503, "No game delegate available")
	if method == "GET":
		match path:
			"/state":
				return _ok(_state())
			"/nodes":
				return _ok(callbacks.nodes.call() if _has_callback("nodes") else [])
			"/actions":
				var state := _state()
				return _ok({"scene": state.get("scene", "MainMenuScene"), "actions": ACTIONS if state.get("scene") == "GameScene" else ACTIONS.slice(0, 2)})
			"/screenshot":
				if not _has_callback("screenshot"):
					return _http_error(503, "Screenshot unavailable")
				var png: Variant = callbacks.screenshot.call()
				if not png is PackedByteArray or png.is_empty():
					return _http_error(503, "Screenshot unavailable in headless mode")
				return _ok({"success": true, "format": "png", "data": Marshalls.raw_to_base64(png)})
	if method != "POST" or path not in ["/tap", "/swipe", "/action"]:
		return _http_error(404, "Not found: %s %s" % [method, path])
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _http_error(400, "Invalid command JSON")
	var request: Dictionary = parser.data
	match path:
		"/action":
			if not request.get("name") is String or str(request.name).is_empty() or not request.get("params", {}) is Dictionary:
				return _http_error(400, "Expected an action name and string parameters")
			for value: Variant in request.get("params", {}).values():
				if not value is String:
					return _http_error(400, "Expected string action parameters")
			if not _has_callback("action"):
				return _http_error(503, "Actions unavailable")
			var result: Dictionary = callbacks.action.call(request.name, request.get("params", {}))
			result["gameState"] = _state()
			return _ok(result)
		"/tap":
			var point := Vector2.ZERO
			if request.get("node") is String and _has_callback("nodes"):
				var found: bool = false
				for node: Dictionary in callbacks.nodes.call():
					if node.get("name") == request.node:
						var frame: Dictionary = node.frame
						point = Vector2(float(frame.x) + float(frame.width) / 2, float(frame.y) + float(frame.height) / 2)
						found = true
						break
				if not found:
					return _command(false, "Node not found: " + request.node)
			elif AtomicJSON.is_number(request.get("x")) and AtomicJSON.is_number(request.get("y")):
				point = Vector2(float(request.x), float(request.y))
			else:
				return _http_error(400, "Either node or finite x,y coordinates are required")
			return _command(bool(callbacks.tap.call(point)) if _has_callback("tap") else false, "Tap injected")
		"/swipe":
			for key: String in ["fromX", "fromY", "toX", "toY", "duration"]:
				if not AtomicJSON.is_number(request.get(key, 0.3 if key == "duration" else null)):
					return _http_error(400, "Expected finite drag coordinates and duration")
			var duration := float(request.get("duration", 0.3))
			if duration < 0:
				return _http_error(400, "Duration must be nonnegative")
			var start := Vector2(float(request.fromX), float(request.fromY))
			var finish := Vector2(float(request.toX), float(request.toY))
			return _command(bool(callbacks.swipe.call(start, finish, duration)) if _has_callback("swipe") else false, "Swipe injected")
	return _http_error(404, "Unknown command")


func _state() -> Dictionary:
	var state: Dictionary = callbacks.state.call()
	state["engine"] = "Godot"
	state["coordinateSystem"] = {"world": "logical pixels, y up", "input": "viewport pixels, top-left origin", "projection": "isometric"}
	return state


func _has_callback(key: String) -> bool:
	return callbacks.get(key) is Callable and callbacks[key].is_valid()


func _command(success: bool, message: String) -> Dictionary:
	var result: Dictionary = {"success": success, "gameState": _state()}
	result["message" if success else "error"] = message if success else "Input was not handled"
	return _ok(result)


static func _ok(data: Variant) -> Dictionary:
	return {"status": 200, "body": data}


static func _http_error(status: int, message: String) -> Dictionary:
	return {"status": status, "body": {"success": false, "error": message}}


static func _rejected(status: int, message: String) -> Dictionary:
	return {"complete": true, "success": false, "status": status, "error": message}


static func _response_bytes(response: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(response.body).to_utf8_buffer()
	var reasons: Dictionary = {200: "OK", 400: "Bad Request", 404: "Not Found", 413: "Payload Too Large", 500: "Internal Server Error", 503: "Service Unavailable"}
	var headers := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [response.status, reasons.get(response.status, "Error"), body.size()]
	var payload := headers.to_utf8_buffer()
	payload.append_array(body)
	return payload
