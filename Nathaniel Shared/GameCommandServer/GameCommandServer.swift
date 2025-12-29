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
            let gameStatus: String // "playing", "paused", "victory", "gameOver"
            let isPaused: Bool
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

        // MARK: - Types for Scene Change Notifications

        public struct SceneChangeEvent: Codable {
            let previousScene: String?
            let currentScene: String
            let timestamp: TimeInterval
            let timedOut: Bool
        }

        private struct PendingSceneWaiter {
            let connection: NWConnection
            let expectedScene: String?
            let deadline: Date
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

        /// Track the current scene name for change detection
        private var currentSceneName: String?

        /// Pending connections waiting for scene changes
        private var sceneWaiters: [PendingSceneWaiter] = []

        /// Timer for checking waiter timeouts
        private var waiterTimeoutTimer: Timer?

        // MARK: - Initialization

        public init(port: UInt16 = 8_765) {
            self.port = port
            setupSceneChangeObserver()
        }

        private func setupSceneChangeObserver() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSceneChange(_:)),
                name: .skViewDidPresentScene,
                object: nil
            )
        }

        @objc
        private func handleSceneChange(_ notification: Notification) {
            // Get the new scene name from the delegate
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let newSceneName = delegate?.getCurrentGameState().scene ?? "Unknown"
                let previousScene = currentSceneName
                currentSceneName = newSceneName

                // Only notify if scene actually changed
                if previousScene != newSceneName {
                    notifySceneWaiters(previousScene: previousScene, newScene: newSceneName)
                }
            }
        }

        private func notifySceneWaiters(previousScene: String?, newScene: String) {
            queue.async { [weak self] in
                guard let self else { return }

                // Find waiters that should be notified
                let (toNotify, remaining) = sceneWaiters.reduce(
                    into: ([PendingSceneWaiter](), [PendingSceneWaiter]())
                ) { result, waiter in
                    // Notify if no expected scene specified, or if it matches
                    if waiter.expectedScene == nil || waiter.expectedScene == newScene {
                        result.0.append(waiter)
                    } else {
                        result.1.append(waiter)
                    }
                }

                sceneWaiters = remaining

                // Send response to each notified waiter
                let event = SceneChangeEvent(
                    previousScene: previousScene,
                    currentScene: newScene,
                    timestamp: Date().timeIntervalSince1970,
                    timedOut: false
                )

                for waiter in toNotify {
                    sendCodableResponse(connection: waiter.connection, value: event)
                }
            }
        }

        private func checkWaiterTimeouts() {
            queue.async { [weak self] in
                guard let self else { return }
                let now = Date()

                let (timedOut, remaining) = sceneWaiters.reduce(
                    into: ([PendingSceneWaiter](), [PendingSceneWaiter]())
                ) { result, waiter in
                    if now >= waiter.deadline {
                        result.0.append(waiter)
                    } else {
                        result.1.append(waiter)
                    }
                }

                sceneWaiters = remaining

                // Send timeout response to timed out waiters
                for waiter in timedOut {
                    let currentScene = currentSceneName ?? "Unknown"
                    let event = SceneChangeEvent(
                        previousScene: nil,
                        currentScene: currentScene,
                        timestamp: Date().timeIntervalSince1970,
                        timedOut: true
                    )
                    sendCodableResponse(connection: waiter.connection, value: event)
                }
            }
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

                listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleNewConnection(connection)
                }

                listener?.start(queue: queue)

                // Start timeout checker timer on main queue
                DispatchQueue.main.async { [weak self] in
                    self?.waiterTimeoutTimer = Timer
                        .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                            self?.checkWaiterTimeouts()
                        }
                }

            } catch {
                print("[GameCommandServer] Failed to create listener: \(error)")
            }
        }

        /// Stop the HTTP server
        public func stop() {
            listener?.cancel()
            listener = nil
            isRunning = false

            // Stop timeout timer
            waiterTimeoutTimer?.invalidate()
            waiterTimeoutTimer = nil

            // Close all connections
            for connection in connections {
                connection.cancel()
            }
            connections.removeAll()

            // Cancel all pending scene waiters
            for waiter in sceneWaiters {
                waiter.connection.cancel()
            }
            sceneWaiters.removeAll()

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
                    if let connection {
                        self?.connections.removeAll { $0 === connection }
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }

        private func receiveRequest(from connection: NWConnection) {
            connection
                .receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
                    if let data, !data.isEmpty {
                        self?.handleRequest(data: data, connection: connection)
                    }

                    if let error {
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

            case ("GET", "/screenshot/annotated"):
                handleAnnotatedScreenshot(connection: connection)

            case ("GET", "/describe"):
                handleDescribe(connection: connection)

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

            case ("GET", _) where path.hasPrefix("/wait_for_scene"):
                handleWaitForScene(path: path, connection: connection)

            default:
                sendErrorResponse(connection: connection, status: 404, message: "Not found: \(method) \(path)")
            }
        }

        // MARK: - Request Handlers

        private func handleHealth(connection: NWConnection) {
            let response: [String: Any] = [
                "status": "ok",
                "server": "GameCommandServer",
                "version": "1.0.0",
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

        private func handleAnnotatedScreenshot(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let delegate = self?.delegate else {
                    self?.sendErrorResponse(connection: connection, status: 503, message: "No game delegate available")
                    return
                }

                // Get nodes and screenshot
                let nodes = delegate.getInteractiveNodes()
                guard let imageData = delegate.captureAnnotatedScreenshot(nodes: nodes) else {
                    self?.sendErrorResponse(
                        connection: connection,
                        status: 503,
                        message: "Failed to capture annotated screenshot"
                    )
                    return
                }

                let base64 = imageData.base64EncodedString()
                let response: [String: Any] = [
                    "success": true,
                    "format": "png",
                    "data": base64,
                    "nodeCount": nodes.count,
                ]
                self?.sendJSONResponse(connection: connection, json: response)
            }
        }

        private func handleDescribe(connection: NWConnection) {
            DispatchQueue.main.async { [weak self] in
                guard let delegate = self?.delegate else {
                    self?.sendErrorResponse(connection: connection, status: 503, message: "No game delegate available")
                    return
                }

                let state = delegate.getCurrentGameState()
                let nodes = delegate.getInteractiveNodes()

                // Build semantic description
                let description = self?.buildSceneDescription(state: state, nodes: nodes) ?? [:]
                self?.sendJSONResponse(connection: connection, json: description)
            }
        }

        /// Build a semantic description of the current scene for agent understanding
        private func buildSceneDescription(state: GameState, nodes: [NodeInfo]) -> [String: Any] {
            var description: [String: Any] = [:]

            // Scene summary
            var summary = "\(state.scene)"
            if state.scene == "GameScene" {
                summary += " - \(state.gameStatus)"
                if state.isPaused {
                    summary += " (PAUSED)"
                }
            }
            description["summary"] = summary

            // Player status
            var playerStatus = ""
            if let playerPos = state.playerPosition {
                playerStatus = "Nathaniel at (\(Int(playerPos.x)), \(Int(playerPos.y)))"
            }
            // Find Nathaniel's health from nodes
            if let nathaniel = nodes.first(where: { $0.name == "nathaniel" }),
               let health = nathaniel.properties?["health"]
            {
                playerStatus += ", health \(health)"
            }
            if let hermesPos = state.hermesPosition {
                playerStatus += ". Hermes at (\(Int(hermesPos.x)), \(Int(hermesPos.y)))"
            }
            if let hermes = nodes.first(where: { $0.name == "hermes" }),
               let isAlive = hermes.properties?["isAlive"]
            {
                if isAlive == "false" {
                    playerStatus += " (DEAD)"
                } else if let health = hermes.properties?["health"] {
                    playerStatus += ", health \(health)"
                }
            }
            description["playerStatus"] = playerStatus

            // Threat summary
            let enemies = nodes.filter { $0.name.hasPrefix("enemy_") }
            if !enemies.isEmpty {
                var threatSummary = "\(enemies.count) enemies"
                // Calculate nearest enemy distance if player position available
                if let playerPos = state.playerPosition {
                    let distances = enemies.compactMap { enemy -> CGFloat? in
                        let centerX = enemy.frame.x + enemy.frame.width / 2
                        let centerY = enemy.frame.y + enemy.frame.height / 2
                        let dx = centerX - playerPos.x
                        let dy = centerY - playerPos.y
                        return sqrt(dx * dx + dy * dy)
                    }
                    if let nearest = distances.min() {
                        threatSummary += ", nearest at \(Int(nearest)) units"
                    }
                }
                description["threats"] = threatSummary
            } else {
                description["threats"] = "No enemies"
            }

            // UI elements
            let uiNodes = nodes.filter { node in
                node.name.contains("Button") || node.name.contains("button") ||
                    node.name == "pauseButton" || node.name == "toggleButton" ||
                    node.type == "SKLabelNode"
            }
            if !uiNodes.isEmpty {
                let uiNames = uiNodes.map(\.name).joined(separator: ", ")
                description["ui"] = "UI elements: \(uiNames)"
            }

            // Game info
            if state.scene == "GameScene" {
                description["score"] = state.score
                description["lives"] = state.lives
                description["resources"] = state.resources
                description["elapsedTime"] = Int(state.elapsedTime)
            }

            // Suggestions based on state
            var suggestions: [String] = []
            if let hermes = nodes.first(where: { $0.name == "hermes" }),
               hermes.properties?["isAlive"] == "false"
            {
                suggestions.append("Hermes is dead - consider reviving")
            }
            if state.enemyCount > 5 {
                suggestions.append("Many enemies present - consider building towers or retreating")
            }
            if state.resources > 50 {
                suggestions.append("Resources available for tower building")
            }
            if !suggestions.isEmpty {
                description["suggestions"] = suggestions
            }

            // Raw counts for programmatic use
            description["enemyCount"] = state.enemyCount
            description["nodeCount"] = nodes.count

            return description
        }

        private func handleTap(body: Data?, connection: NWConnection) {
            guard let body,
                  let request = try? JSONDecoder().decode(TapRequest.self, from: body)
            else {
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
            guard let body,
                  let request = try? JSONDecoder().decode(SwipeRequest.self, from: body)
            else {
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
            guard let body,
                  let request = try? JSONDecoder().decode(ActionRequest.self, from: body)
            else {
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
            guard let body else {
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
                    "settings": self?.settingsToDictionary() ?? [:],
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
                    "settings": self?.settingsToDictionary() ?? [:],
                ]
                self?.sendJSONResponse(connection: connection, json: response)
            }
        }

        // MARK: - Scene Change Notification Handler

        private func handleWaitForScene(path: String, connection: NWConnection) {
            // Parse query parameters from path (e.g., /wait_for_scene?timeout=10&scene=GameScene)
            let params = parseQueryParameters(from: path)

            let timeout = Double(params["timeout"] ?? "") ?? 10.0
            let expectedScene = params["scene"]

            // Check if we're already at the expected scene
            if let expectedScene {
                DispatchQueue.main.async { [weak self] in
                    let currentScene = self?.delegate?.getCurrentGameState().scene ?? "Unknown"
                    if currentScene == expectedScene {
                        // Already at expected scene - return immediately
                        let event = SceneChangeEvent(
                            previousScene: nil,
                            currentScene: currentScene,
                            timestamp: Date().timeIntervalSince1970,
                            timedOut: false
                        )
                        self?.sendCodableResponse(connection: connection, value: event)
                        return
                    }

                    // Not at expected scene - add to waiters
                    self?.addSceneWaiter(connection: connection, expectedScene: expectedScene, timeout: timeout)
                }
            } else {
                // No expected scene - wait for any scene change
                addSceneWaiter(connection: connection, expectedScene: nil, timeout: timeout)
            }
        }

        private func addSceneWaiter(connection: NWConnection, expectedScene: String?, timeout: TimeInterval) {
            let deadline = Date().addingTimeInterval(timeout)
            let waiter = PendingSceneWaiter(
                connection: connection,
                expectedScene: expectedScene,
                deadline: deadline
            )

            queue.async { [weak self] in
                self?.sceneWaiters.append(waiter)
            }
        }

        private func parseQueryParameters(from path: String) -> [String: String] {
            guard let queryStart = path.firstIndex(of: "?") else {
                return [:]
            }

            let queryString = String(path[path.index(after: queryStart)...])
            var params: [String: String] = [:]

            for pair in queryString.components(separatedBy: "&") {
                let parts = pair.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].removingPercentEncoding ?? parts[0]
                    let value = parts[1].removingPercentEncoding ?? parts[1]
                    params[key] = value
                }
            }

            return params
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
                "showCollisionBounds": settings.showCollisionBounds,
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

        private func sendCodableResponse(connection: NWConnection, value: some Encodable, status: Int = 200) {
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
                "error": message,
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
            case 404: "Not Found"
            case 500: "Internal Server Error"
            case 503: "Service Unavailable"
            default: "Unknown"
            }
        }
    }

#endif
