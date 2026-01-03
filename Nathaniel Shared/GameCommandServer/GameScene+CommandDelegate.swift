#if DEBUG

//
    //  GameScene+CommandDelegate.swift
    //  Nathaniel Shared
//
    //  GameCommandDelegate implementation for GameScene.
    //  Uses the GameActionRegistry for action dispatch.
//

    import SpriteKit

    extension GameScene: GameCommandDelegate {
        // MARK: - State Queries

        public func getCurrentGameState() -> GameCommandServer.GameState {
            // Determine game status and pause state
            let status: String
            let isPaused: Bool
            let levelInfo = self.findLevelManagerPublic()

            if levelInfo?.isPaused == true {
                status = "paused"
                isPaused = true
            } else if let overlay = children.first(where: { $0 is GameOverlay }) as? GameOverlay {
                isPaused = false
                switch overlay.state {
                case .hidden:
                    status = "playing"
                case .victory:
                    status = "victory"
                case .gameOver:
                    status = "gameOver"
                case .lifeLost:
                    status = "lifeLost"
                }
            } else {
                status = "playing"
                isPaused = false
            }

            // Get player positions
            var nathanielPos: GameCommandServer.PointInfo?
            var hermesPos: GameCommandServer.PointInfo?

            if let nathaniel = findNathanielPublic() {
                nathanielPos = GameCommandServer.PointInfo(x: nathaniel.position.x, y: nathaniel.position.y)
            }

            if let hermes = findHermesPublic() {
                hermesPos = GameCommandServer.PointInfo(x: hermes.position.x, y: hermes.position.y)
            }

            return GameCommandServer.GameState(
                scene: "GameScene",
                score: levelInfo?.score ?? 0,
                lives: levelInfo?.lives ?? 0,
                resources: ResourceManager.shared.totalCollected,
                elapsedTime: levelInfo?.elapsedTime ?? 0,
                gameStatus: status,
                isPaused: isPaused,
                playerPosition: nathanielPos,
                hermesPosition: hermesPos,
                enemyCount: self.findEnemyManagerPublic()?.aliveCount ?? 0
            )
        }

        public func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
            var nodes: [GameCommandServer.NodeInfo] = []

            // Add player characters
            if let nathaniel = findNathanielPublic() {
                let frame = nathaniel.sprite.frame
                nodes.append(GameCommandServer.NodeInfo(
                    name: "nathaniel",
                    type: "Player",
                    frame: GameCommandServer.FrameInfo(
                        x: frame.origin.x,
                        y: frame.origin.y,
                        width: frame.size.width,
                        height: frame.size.height
                    ),
                    interactive: true,
                    properties: [
                        "health": "\(nathaniel.currentHP)/\(nathaniel.maxHP)",
                        "isAlive": "\(nathaniel.isAlive)",
                    ]
                ))
            }

            if let hermes = findHermesPublic() {
                let frame = hermes.sprite.frame

                // Calculate distance to Nathaniel if in follow mode
                var distanceToTarget: CGFloat = 0
                if let nathaniel = findNathanielPublic() {
                    let dx = nathaniel.position.x - hermes.position.x
                    let dy = nathaniel.position.y - hermes.position.y
                    distanceToTarget = sqrt(dx * dx + dy * dy)
                }

                // Map mode enum to string
                let modeString = switch hermes.mode {
                case .following: "following"
                case .independent: "independent"
                case .locked: "locked"
                }

                nodes.append(GameCommandServer.NodeInfo(
                    name: "hermes",
                    type: "Companion",
                    frame: GameCommandServer.FrameInfo(
                        x: frame.origin.x,
                        y: frame.origin.y,
                        width: frame.size.width,
                        height: frame.size.height
                    ),
                    interactive: true,
                    properties: [
                        "health": "\(hermes.currentHP)/\(hermes.maxHP)",
                        "isAlive": "\(hermes.isAlive)",
                        "mode": modeString,
                        "isInBuildMode": "\(hermes.isInBuildMode)",
                        "followTarget": "Nathaniel",
                        "distanceToTarget": String(format: "%.1f", distanceToTarget),
                    ]
                ))
            }

            // Add enemies
            if let enemyManager = findEnemyManagerPublic() {
                for (index, enemy) in enemyManager.enemies.enumerated() where enemy.isAlive {
                    let frame = enemy.sprite.frame
                    nodes.append(GameCommandServer.NodeInfo(
                        name: "enemy_\(index)",
                        type: "Enemy",
                        frame: GameCommandServer.FrameInfo(
                            x: frame.origin.x,
                            y: frame.origin.y,
                            width: frame.size.width,
                            height: frame.size.height
                        ),
                        interactive: true,
                        properties: [
                            "health": "\(enemy.currentHP)/\(enemy.maxHP)",
                        ]
                    ))
                }
            }

            // Add HUD elements
            if let hud = findHUDPublic() {
                nodes.append(hud.toNodeInfo(interactive: true, properties: ["type": "HUD"]))
            }

            return nodes
        }

        public func captureScreenshot() -> Data? {
            captureAsPNG()
        }

        // MARK: - Input Injection

        public func injectTap(at point: CGPoint) -> Bool {
            // Check if build menu should handle this tap (close if outside)
            if handleTapWithBuildMenuCheck(at: point) {
                return true
            }

            // Use the existing handleTap method for other interactions
            handleTap(at: point)
            return true
        }

        public func injectSwipe(from: CGPoint, to: CGPoint, duration: CGFloat) -> Bool {
            // For game purposes, a swipe is essentially a move command from start to end
            // We'll treat it as tapping the end point (move to destination)
            handleTap(at: to)
            return true
        }

        // MARK: - Custom Actions

        public func executeAction(name: String, params: [String: String]?) -> ActionResult {
            let context = GameActionContext(scene: self)

            // Try the registry first
            if let result = GameActionRegistry.shared.execute(name: name, params: params, context: context) {
                return result
            }

            // Action not found
            return .failure("Unknown action: \(name)")
        }

        // MARK: - Public Accessors for Action Handlers

        func findNathanielPublic() -> Nathaniel? {
            self.findNathaniel()
        }

        func findHermesPublic() -> Hermes? {
            self.findHermes()
        }

        func findEnemyManagerPublic() -> EnemyManager? {
            self.findEnemyManager()
        }

        func findLevelManagerPublic() -> LevelManager? {
            self.findLevelManager()
        }

        func findHUDPublic() -> HUD? {
            self.findHUD()
        }

        func findPauseMenuPublic() -> PauseMenu? {
            self.findPauseMenu()
        }

        func findSaveSlotSelectorPublic() -> SaveSlotSelector? {
            self.findSaveSlotSelector()
        }

        func findSettingsMenuPublic() -> SettingsMenu? {
            self.findSettingsMenu()
        }

        func findStructureManagerPublic() -> StructureManager? {
            self.findStructureManager()
        }

        func findCameraNodePublic() -> SKCameraNode? {
            self.findCameraNode()
        }

        // MARK: - Private Helper Methods

        private func findNathaniel() -> Nathaniel? {
            // Look for Nathaniel sprite in scene
            for child in children {
                if let nathaniel = child.userData?["character"] as? Nathaniel {
                    return nathaniel
                }
            }
            // Fallback: use Mirror to access private property
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "nathaniel", let nathaniel = child.value as? Nathaniel {
                    return nathaniel
                }
            }
            return nil
        }

        private func findHermes() -> Hermes? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "hermes", let hermes = child.value as? Hermes {
                    return hermes
                }
            }
            return nil
        }

        private func findEnemyManager() -> EnemyManager? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "enemyManager", let manager = child.value as? EnemyManager {
                    return manager
                }
            }
            return nil
        }

        private func findLevelManager() -> LevelManager? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "levelManager", let manager = child.value as? LevelManager {
                    return manager
                }
            }
            return nil
        }

        private func findHUD() -> HUD? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "hud", let hud = child.value as? HUD {
                    return hud
                }
            }
            return nil
        }

        private func findPauseMenu() -> PauseMenu? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "pauseMenu", let pauseMenu = child.value as? PauseMenu {
                    return pauseMenu
                }
            }
            return nil
        }

        private func findSaveSlotSelector() -> SaveSlotSelector? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "saveSlotSelector", let selector = child.value as? SaveSlotSelector {
                    return selector
                }
            }
            return nil
        }

        private func findSettingsMenu() -> SettingsMenu? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "settingsMenu", let menu = child.value as? SettingsMenu {
                    return menu
                }
            }
            return nil
        }

        private func findStructureManager() -> StructureManager? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "structureManager", let manager = child.value as? StructureManager {
                    return manager
                }
            }
            return nil
        }

        private func findCameraNode() -> SKCameraNode? {
            let mirror = Mirror(reflecting: self)
            for child in mirror.children {
                if child.label == "cameraNode", let camera = child.value as? SKCameraNode {
                    return camera
                }
            }
            return nil
        }
    }

#endif
