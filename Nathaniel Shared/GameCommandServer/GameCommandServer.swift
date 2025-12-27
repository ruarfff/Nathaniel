//
//  GameCommandServer.swift
//  Nathaniel Shared
//
//  Lightweight HTTP server for agent/LLM game testing.
//  Only compiled in DEBUG builds.
//

#if DEBUG

import Foundation
import Network
import SpriteKit

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when SKView presents a new scene
    static let skViewDidPresentScene = Notification.Name("skViewDidPresentScene")
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
        let gameStatus: String  // "playing", "victory", "gameOver"
        let playerPosition: PointInfo?
        let hermesPosition: PointInfo?
        let enemyCount: Int
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
        let x: CGFloat
        let y: CGFloat
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

    public init(port: UInt16 = 8765) {
        self.port = port
    }

    // MARK: - Server Control

    /// Start the HTTP server
    public func start() {
        guard !isRunning else {
            print("[GameCommandServer] Already running on port \(port)")
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("[GameCommandServer] Listening on port \(self?.port ?? 0)")
                    self?.isRunning = true
                case .failed(let error):
                    print("[GameCommandServer] Listener failed: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    print("[GameCommandServer] Listener cancelled")
                    self?.isRunning = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.start(queue: queue)

        } catch {
            print("[GameCommandServer] Failed to create listener: \(error)")
        }
    }

    /// Stop the HTTP server
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false

        // Close all connections
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()

        print("[GameCommandServer] Stopped")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                self?.receiveRequest(from: connection!)
            case .failed, .cancelled:
                if let connection = connection {
                    self?.connections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleRequest(data: data, connection: connection)
            }

            if let error = error {
                print("[GameCommandServer] Receive error: \(error)")
                connection.cancel()
            } else if isComplete {
                connection.cancel()
            }
        }
    }

    // MARK: - HTTP Request Handling

    private func handleRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid request encoding")
            return
        }

        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendErrorResponse(connection: connection, status: 400, message: "Empty request")
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid request line")
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Extract body (after blank line)
        var body: Data? = nil
        if let blankLineIndex = lines.firstIndex(of: "") {
            let bodyString = lines.dropFirst(blankLineIndex + 1).joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        // Route the request
        routeRequest(method: method, path: path, body: body, connection: connection)
    }

    private func routeRequest(method: String, path: String, body: Data?, connection: NWConnection) {
        switch (method, path) {
        case ("GET", "/health"):
            handleHealth(connection: connection)

        case ("GET", "/state"):
            handleGetState(connection: connection)

        case ("GET", "/nodes"):
            handleGetNodes(connection: connection)

        case ("GET", "/screenshot"):
            handleScreenshot(connection: connection)

        case ("POST", "/tap"):
            handleTap(body: body, connection: connection)

        case ("POST", "/swipe"):
            handleSwipe(body: body, connection: connection)

        case ("POST", "/action"):
            handleAction(body: body, connection: connection)

        case ("GET", "/settings"):
            handleGetSettings(connection: connection)

        case ("POST", "/settings"):
            handleSetSettings(body: body, connection: connection)

        case ("POST", "/settings/reset"):
            handleResetSettings(connection: connection)

        default:
            sendErrorResponse(connection: connection, status: 404, message: "Not found: \(method) \(path)")
        }
    }

    // MARK: - Request Handlers

    private func handleHealth(connection: NWConnection) {
        let response: [String: Any] = [
            "status": "ok",
            "server": "GameCommandServer",
            "version": "1.0.0"
        ]
        sendJSONResponse(connection: connection, json: response)
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
                self?.sendErrorResponse(connection: connection, status: 503, message: "Failed to capture screenshot")
                return
            }

            let base64 = imageData.base64EncodedString()
            let response: [String: Any] = [
                "success": true,
                "format": "png",
                "data": base64
            ]
            self?.sendJSONResponse(connection: connection, json: response)
        }
    }

    private func handleTap(body: Data?, connection: NWConnection) {
        guard let body = body,
              let request = try? JSONDecoder().decode(TapRequest.self, from: body) else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid tap request body")
            return
        }

        DispatchQueue.main.async { [weak self] in
            let point = CGPoint(x: request.x, y: request.y)
            let success = self?.delegate?.injectTap(at: point) ?? false

            // Get updated state after tap
            let state = self?.delegate?.getCurrentGameState()

            let response = CommandResponse(
                success: success,
                message: success ? "Tap injected at (\(request.x), \(request.y))" : "Tap failed",
                gameState: state,
                error: success ? nil : "Failed to inject tap"
            )
            self?.sendCodableResponse(connection: connection, value: response)
        }
    }

    private func handleSwipe(body: Data?, connection: NWConnection) {
        guard let body = body,
              let request = try? JSONDecoder().decode(SwipeRequest.self, from: body) else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid swipe request body")
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
        guard let body = body,
              let request = try? JSONDecoder().decode(ActionRequest.self, from: body) else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid action request body")
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

    // MARK: - Settings Handlers

    private func handleGetSettings(connection: NWConnection) {
        DispatchQueue.main.async { [weak self] in
            let settings = DevSettings.shared
            self?.sendCodableResponse(connection: connection, value: settings)
        }
    }

    private func handleSetSettings(body: Data?, connection: NWConnection) {
        guard let body = body else {
            sendErrorResponse(connection: connection, status: 400, message: "Missing request body")
            return
        }

        // Parse JSON as dictionary for partial updates
        guard let updates = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            sendErrorResponse(connection: connection, status: 400, message: "Invalid JSON in request body")
            return
        }

        DispatchQueue.main.async { [weak self] in
            let updatedCount = DevSettings.shared.apply(updates: updates)

            let response: [String: Any] = [
                "success": true,
                "message": "Updated \(updatedCount) setting(s)",
                "settings": self?.settingsToDictionary() ?? [:]
            ]
            self?.sendJSONResponse(connection: connection, json: response)
        }
    }

    private func handleResetSettings(connection: NWConnection) {
        DispatchQueue.main.async { [weak self] in
            DevSettings.shared.reset()

            let response: [String: Any] = [
                "success": true,
                "message": "All settings reset to defaults",
                "settings": self?.settingsToDictionary() ?? [:]
            ]
            self?.sendJSONResponse(connection: connection, json: response)
        }
    }

    /// Convert DevSettings to dictionary for JSON response
    private func settingsToDictionary() -> [String: Any] {
        let settings = DevSettings.shared
        return [
            // Player settings
            "nathanielSpeed": settings.nathanielSpeed,
            "hermesSpeed": settings.hermesSpeed,
            "nathanielMaxHealth": settings.nathanielMaxHealth,
            "hermesMaxHealth": settings.hermesMaxHealth,
            "playerInvincible": settings.playerInvincible,
            "respawnDelay": settings.respawnDelay,
            // Enemy settings
            "gruntSpeed": settings.gruntSpeed,
            "soldierSpeed": settings.soldierSpeed,
            "bossSpeed": settings.bossSpeed,
            "enemyVisibleRange": settings.enemyVisibleRange,
            "enemyAttackRange": settings.enemyAttackRange,
            "enemyDamage": settings.enemyDamage,
            // Projectile settings
            "bulletSpeed": settings.bulletSpeed,
            "arrowSpeed": settings.arrowSpeed,
            "projectileDamage": settings.projectileDamage,
            // Spawn settings
            "spawnInterval": settings.spawnInterval,
            // Camera settings
            "cameraZoom": settings.cameraZoom,
            "cameraMinZoom": settings.cameraMinZoom,
            "cameraMaxZoom": settings.cameraMaxZoom,
            "cameraFollowSmoothing": settings.cameraFollowSmoothing,
            "cameraFreeMode": settings.cameraFreeMode,
            // Tower settings
            "towerDamage": settings.towerDamage,
            "towerRange": settings.towerRange,
            "towerCostGun": settings.towerCostGun,
            "towerCostLaser": settings.towerCostLaser,
            "towerCostHeal": settings.towerCostHeal,
            "instantBuild": settings.instantBuild,
            // Debug toggles
            "infiniteResources": settings.infiniteResources,
            "showDebugInfo": settings.showDebugInfo,
            "showCollisionBounds": settings.showCollisionBounds
        ]
    }

    // MARK: - Response Helpers

    private func sendJSONResponse(connection: NWConnection, json: [String: Any], status: Int = 200) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            sendHTTPResponse(connection: connection, status: status, contentType: "application/json", body: data)
        } catch {
            sendErrorResponse(connection: connection, status: 500, message: "JSON serialization failed")
        }
    }

    private func sendCodableResponse<T: Encodable>(connection: NWConnection, value: T, status: Int = 200) {
        do {
            let data = try JSONEncoder().encode(value)
            sendHTTPResponse(connection: connection, status: status, contentType: "application/json", body: data)
        } catch {
            sendErrorResponse(connection: connection, status: 500, message: "Encoding failed: \(error)")
        }
    }

    private func sendErrorResponse(connection: NWConnection, status: Int, message: String) {
        let json: [String: Any] = [
            "success": false,
            "error": message
        ]
        sendJSONResponse(connection: connection, json: json, status: status)
    }

    private func sendHTTPResponse(connection: NWConnection, status: Int, contentType: String, body: Data) {
        let statusText = httpStatusText(for: status)
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
            if let error = error {
                print("[GameCommandServer] Send error: \(error)")
            }
            connection.cancel()
        })
    }

    private func httpStatusText(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }
}

#endif
