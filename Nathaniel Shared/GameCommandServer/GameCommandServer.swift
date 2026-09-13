//
//  GameCommandServer.swift
//  Nathaniel Shared
//
//  Serves HTTP commands for inspecting and controlling debug builds.
//

#if DEBUG

    import Foundation
    import Network
    import SpriteKit

    /// Byte framing for the server's single-request HTTP connections.
    private enum HTTPRequestResult {
        case incomplete
        case complete(method: String, path: String, body: Data)
        case rejected(status: Int, message: String)

        private static let maximumHeaderBytes = 16_384
        private static let maximumBodyBytes = 16 * 1_024 * 1_024

        static func parse(_ data: Data) -> Self {
            guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
                return data.count > self.maximumHeaderBytes
                    ? .rejected(status: 413, message: "HTTP headers too large")
                    : .incomplete
            }
            guard separator.upperBound <= self.maximumHeaderBytes else {
                return .rejected(status: 413, message: "HTTP headers too large")
            }
            guard let header = String(data: data[..<separator.lowerBound], encoding: .utf8) else {
                return .rejected(status: 400, message: "Invalid request encoding")
            }
            let lines = header.components(separatedBy: "\r\n")
            let parts = (lines.first ?? "").components(separatedBy: " ")
            guard parts.count == 3, parts[2].hasPrefix("HTTP/1.") else {
                return .rejected(status: 400, message: "Invalid request line")
            }

            var contentLength: Int?
            for line in lines.dropFirst() {
                guard let colon = line.firstIndex(of: ":") else {
                    return .rejected(status: 400, message: "Invalid HTTP header")
                }
                let name = line[..<colon].lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if name == "transfer-encoding" {
                    return .rejected(status: 400, message: "Transfer-Encoding is not supported")
                }
                if name == "content-length" {
                    guard contentLength == nil, !value.isEmpty,
                          value.utf8.allSatisfy({ (48 ... 57).contains($0) }), let length = Int(value)
                    else {
                        return .rejected(status: 400, message: "Invalid Content-Length")
                    }
                    contentLength = length
                }
            }

            let bodyLength = contentLength ?? 0
            guard bodyLength <= self.maximumBodyBytes else {
                return .rejected(status: 413, message: "HTTP body too large")
            }
            let requestEnd = separator.upperBound + bodyLength
            guard data.count >= requestEnd else { return .incomplete }
            return .complete(
                method: parts[0],
                path: parts[1],
                body: data.subdata(in: separator.upperBound ..< requestEnd)
            )
        }
    }

    /// HTTP server that allows agents to control and inspect the game
    public class GameCommandServer {
        // MARK: - Types

        public struct GameState: Codable {
            let scene: String
            let score: Int
            let lives: Int
            let resources: Int
            let elapsedTime: TimeInterval
            let gameStatus: String // "playing", "paused", "victory", "gameOver"
            let isPaused: Bool
            let playerPosition: PointInfo?
            let hermesPosition: PointInfo?
            let enemyCount: Int
            var playerHealth: Int?
            var hermesHealth: Int?
            var hermesMode: String?
            var towerCount: Int?
        }

        public struct NodeInfo: Codable {
            let name: String
            let type: String
            let frame: FrameInfo
            let interactive: Bool
            let properties: [String: String]?
        }

        public struct PointInfo: Codable {
            let x: CGFloat
            let y: CGFloat
        }

        public struct FrameInfo: Codable {
            let x: CGFloat
            let y: CGFloat
            let width: CGFloat
            let height: CGFloat
        }

        public struct TapRequest: Codable {
            let x: CGFloat?
            let y: CGFloat?
            let node: String? // Tap by node name (finds center automatically)
        }

        public struct SwipeRequest: Codable {
            let fromX: CGFloat
            let fromY: CGFloat
            let toX: CGFloat
            let toY: CGFloat
            let duration: CGFloat
        }

        public struct ActionRequest: Codable {
            let name: String
            let params: [String: String]?
        }

        public struct CommandResponse: Codable {
            let success: Bool
            let message: String?
            let gameState: GameState?
            let error: String?
        }

        // MARK: - Properties

        public static let shared = GameCommandServer()

        private var listener: NWListener?
        private let port: UInt16
        private var connections: [NWConnection] = []
        private let queue = DispatchQueue(label: "com.ruarfff.nathaniel.commandserver")

        /// The delegate providing game state and accepting commands
        public weak var delegate: GameCommandDelegate?

        /// Whether the server is currently running
        public private(set) var isRunning = false

        // MARK: - Initialization

        public init(port: UInt16 = 8_765) {
            self.port = port
        }

        // MARK: - Server Control

        /// Start the HTTP server
        public func start() {
            guard !self.isRunning else {
                print("[GameCommandServer] Already running on port \(self.port)")
                return
            }

            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true

                self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: self.port)!)

                self.listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        print("[GameCommandServer] Listening on port \(self?.port ?? 0)")
                        self?.isRunning = true
                    case let .failed(error):
                        print("[GameCommandServer] Listener failed: \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        print("[GameCommandServer] Listener cancelled")
                        self?.isRunning = false
                    default:
                        break
                    }
                }

                self.listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleNewConnection(connection)
                }

                self.listener?.start(queue: self.queue)

            } catch {
                print("[GameCommandServer] Failed to create listener: \(error)")
            }
        }

        /// Stop the HTTP server
        public func stop() {
            self.listener?.cancel()
            self.listener = nil
            self.isRunning = false

            // Close all connections
            for connection in self.connections {
                connection.cancel()
            }
            self.connections.removeAll()

            print("[GameCommandServer] Stopped")
        }

        // MARK: - Connection Handling

        private func handleNewConnection(_ connection: NWConnection) {
            self.connections.append(connection)

            connection.stateUpdateHandler = { [weak self, weak connection] state in
                switch state {
                case .ready:
                    if let connection {
                        self?.receiveRequest(from: connection)
                    }
                case .failed, .cancelled:
                    if let connection {
                        self?.connections.removeAll { $0 === connection }
                    }
                default:
                    break
                }
            }

            connection.start(queue: self.queue)
        }

        private func receiveRequest(from connection: NWConnection, buffer: Data = Data()) {
            connection
                .receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
                    guard let self else {
                        connection.cancel()
                        return
                    }
                    var buffer = buffer
                    if let data {
                        buffer.append(data)
                    }
                    switch HTTPRequestResult.parse(buffer) {
                    case let .complete(method, path, body):
                        // Each connection carries one request; the response closes it.
                        self.routeRequest(method: method, path: path, body: body, connection: connection)
                        return
                    case let .rejected(status, message):
                        self.sendErrorResponse(connection: connection, status: status, message: message)
                        return
                    case .incomplete:
                        break
                    }
                    if let error {
                        print("[GameCommandServer] Receive error: \(error)")
                        connection.cancel()
                    } else if isComplete {
                        self.sendErrorResponse(connection: connection, status: 400, message: "Incomplete HTTP request")
                    } else {
                        self.receiveRequest(from: connection, buffer: buffer)
                    }
                }
        }

        // MARK: - HTTP Request Handling

        private func routeRequest(method: String, path: String, body: Data?, connection: NWConnection) {
            switch (method, path) {
            case ("GET", "/health"):
                self.handleHealth(connection: connection)

            case ("GET", "/state"):
                self.handleGetState(connection: connection)

            case ("GET", "/nodes"):
                self.handleGetNodes(connection: connection)

            case ("GET", "/screenshot"):
                self.handleScreenshot(connection: connection)

            case ("POST", "/tap"):
                self.handleTap(body: body, connection: connection)

            case ("POST", "/swipe"):
                self.handleSwipe(body: body, connection: connection)

            case ("POST", "/action"):
                self.handleAction(body: body, connection: connection)

            case ("GET", "/actions"):
                self.handleListActions(connection: connection)

            default:
                self.sendErrorResponse(connection: connection, status: 404, message: "Not found: \(method) \(path)")
            }
        }

        // MARK: - Request Handlers

        private func handleHealth(connection: NWConnection) {
            let response: [String: Any] = [
                "status": "ok",
                "server": "GameCommandServer",
                "version": "1.0.0",
            ]
            self.sendJSONResponse(connection: connection, json: response)
        }

        private func handleGetState(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let state = self?.delegate?.getCurrentGameState() else {
                    self?.sendErrorResponse(connection: connection, status: 503, message: "No game delegate available")
                    return
                }

                self?.sendCodableResponse(connection: connection, value: state)
            }
        }

        private func handleGetNodes(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let nodes = self?.delegate?.getInteractiveNodes() else {
                    self?.sendErrorResponse(connection: connection, status: 503, message: "No game delegate available")
                    return
                }

                self?.sendCodableResponse(connection: connection, value: nodes)
            }
        }

        private func handleScreenshot(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let imageData = self?.delegate?.captureScreenshot() else {
                    self?.sendErrorResponse(
                        connection: connection,
                        status: 503,
                        message: "Failed to capture screenshot"
                    )
                    return
                }

                let base64 = imageData.base64EncodedString()
                let response: [String: Any] = [
                    "success": true,
                    "format": "png",
                    "data": base64,
                ]
                self?.sendJSONResponse(connection: connection, json: response)
            }
        }

        private func handleTap(body: Data?, connection: NWConnection) {
            guard let body,
                  let request = try? JSONDecoder().decode(TapRequest.self, from: body)
            else {
                self.sendErrorResponse(connection: connection, status: 400, message: "Invalid tap request body")
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Mode 2: Tap by node name
                if let nodeName = request.node {
                    guard let nodes = delegate?.getInteractiveNodes() else {
                        let response = CommandResponse(
                            success: false,
                            message: nil,
                            gameState: delegate?.getCurrentGameState(),
                            error: "No delegate available"
                        )
                        self.sendCodableResponse(connection: connection, value: response)
                        return
                    }

                    guard let node = nodes.first(where: { $0.name == nodeName }) else {
                        let response = CommandResponse(
                            success: false,
                            message: nil,
                            gameState: delegate?.getCurrentGameState(),
                            error: "Node '\(nodeName)' not found. Available: \(nodes.map(\.name).joined(separator: ", "))"
                        )
                        self.sendCodableResponse(connection: connection, value: response)
                        return
                    }

                    // Calculate center of node
                    let centerX = node.frame.x + node.frame.width / 2
                    let centerY = node.frame.y + node.frame.height / 2
                    let point = CGPoint(x: centerX, y: centerY)

                    let success = self.delegate?.injectTap(at: point) ?? false
                    let state = self.delegate?.getCurrentGameState()

                    let response = CommandResponse(
                        success: success,
                        message: success
                            ? "Tapped '\(nodeName)' at (\(Int(centerX)), \(Int(centerY)))"
                            : "Tap failed",
                        gameState: state,
                        error: success ? nil : "Failed to inject tap"
                    )
                    self.sendCodableResponse(connection: connection, value: response)
                    return
                }

                // Mode 1: Tap by coordinates
                guard let x = request.x, let y = request.y else {
                    let response = CommandResponse(
                        success: false,
                        message: nil,
                        gameState: delegate?.getCurrentGameState(),
                        error: "Either 'node' name or 'x','y' coordinates are required"
                    )
                    self.sendCodableResponse(connection: connection, value: response)
                    return
                }

                let point = CGPoint(x: x, y: y)
                let success = self.delegate?.injectTap(at: point) ?? false

                // Get updated state after tap
                let state = self.delegate?.getCurrentGameState()

                let response = CommandResponse(
                    success: success,
                    message: success ? "Tap injected at (\(x), \(y))" : "Tap failed",
                    gameState: state,
                    error: success ? nil : "Failed to inject tap"
                )
                self.sendCodableResponse(connection: connection, value: response)
            }
        }

        private func handleSwipe(body: Data?, connection: NWConnection) {
            guard let body,
                  let request = try? JSONDecoder().decode(SwipeRequest.self, from: body)
            else {
                self.sendErrorResponse(connection: connection, status: 400, message: "Invalid swipe request body")
                return
            }

            DispatchQueue.main.async { [weak self] in
                let from = CGPoint(x: request.fromX, y: request.fromY)
                let to = CGPoint(x: request.toX, y: request.toY)
                let success = self?.delegate?.injectSwipe(from: from, to: to, duration: request.duration) ?? false

                let state = self?.delegate?.getCurrentGameState()

                let response = CommandResponse(
                    success: success,
                    message: success ? "Swipe injected" : "Swipe failed",
                    gameState: state,
                    error: success ? nil : "Failed to inject swipe"
                )
                self?.sendCodableResponse(connection: connection, value: response)
            }
        }

        private func handleAction(body: Data?, connection: NWConnection) {
            guard let body,
                  let request = try? JSONDecoder().decode(ActionRequest.self, from: body)
            else {
                self.sendErrorResponse(connection: connection, status: 400, message: "Invalid action request body")
                return
            }

            DispatchQueue.main.async { [weak self] in
                let result = self?.delegate?.executeAction(name: request.name, params: request.params)

                let state = self?.delegate?.getCurrentGameState()
                let success = result?.success ?? false

                let response = CommandResponse(
                    success: success,
                    message: result?.message,
                    gameState: state,
                    error: success ? nil : result?.error
                )
                self?.sendCodableResponse(connection: connection, value: response)
            }
        }

        private func handleListActions(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let scene = self.delegate as? SKScene else {
                    self?.sendErrorResponse(connection: connection, status: 503, message: "No game scene available")
                    return
                }
                self.sendJSONResponse(connection: connection, json: [
                    "scene": String(describing: type(of: scene)),
                    "actions": GameDebugAction.available(in: scene)
                        .map { ["name": $0.rawValue, "params": $0.parameters] },
                ])
            }
        }

        // MARK: - Response Helpers

        private func sendJSONResponse(connection: NWConnection, json: [String: Any], status: Int = 200) {
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                self.sendHTTPResponse(
                    connection: connection,
                    status: status,
                    contentType: "application/json",
                    body: data
                )
            } catch {
                self.sendErrorResponse(connection: connection, status: 500, message: "JSON serialization failed")
            }
        }

        private func sendCodableResponse(connection: NWConnection, value: some Encodable, status: Int = 200) {
            do {
                let data = try JSONEncoder().encode(value)
                self.sendHTTPResponse(
                    connection: connection,
                    status: status,
                    contentType: "application/json",
                    body: data
                )
            } catch {
                self.sendErrorResponse(connection: connection, status: 500, message: "Encoding failed: \(error)")
            }
        }

        private func sendErrorResponse(connection: NWConnection, status: Int, message: String) {
            let json: [String: Any] = [
                "success": false,
                "error": message,
            ]
            self.sendJSONResponse(connection: connection, json: json, status: status)
        }

        private func sendHTTPResponse(connection: NWConnection, status: Int, contentType: String, body: Data) {
            let statusText = self.httpStatusText(for: status)
            let headers = """
            HTTP/1.1 \(status) \(statusText)\r
            Content-Type: \(contentType)\r
            Content-Length: \(body.count)\r
            Connection: close\r
            Access-Control-Allow-Origin: *\r
            \r

            """

            var responseData = headers.data(using: .utf8)!
            responseData.append(body)

            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error {
                    print("[GameCommandServer] Send error: \(error)")
                }
                connection.cancel()
            })
        }

        private func httpStatusText(for status: Int) -> String {
            switch status {
            case 200: "OK"
            case 400: "Bad Request"
            case 413: "Payload Too Large"
            case 404: "Not Found"
            case 500: "Internal Server Error"
            case 503: "Service Unavailable"
            default: "Unknown"
            }
        }
    }

#endif
