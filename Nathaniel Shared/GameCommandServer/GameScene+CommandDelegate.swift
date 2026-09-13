#if DEBUG

//
    //  GameScene+CommandDelegate.swift
    //  Nathaniel Shared
//
    //  GameCommandDelegate implementation for GameScene.
//

    import SpriteKit

    extension GameScene: GameCommandDelegate {
        // MARK: - State Queries

        public func getCurrentGameState() -> GameCommandServer.GameState {
            let levelInfo = self.internalLevelManager
            let isPaused = levelInfo?.state == .paused
            let status = switch levelInfo?.state {
            case .paused: "paused"
            case .victory: "victory"
            case .gameOver: "gameOver"
            default: "playing"
            }

            // Get player positions
            var nathanielPos: GameCommandServer.PointInfo?
            var hermesPos: GameCommandServer.PointInfo?

            if let nathaniel = internalNathaniel {
                nathanielPos = GameCommandServer.PointInfo(x: nathaniel.position.x, y: nathaniel.position.y)
            }

            if let hermes = internalHermes {
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
                enemyCount: self.internalEnemyManager?.aliveCount ?? 0,
                playerHealth: self.internalNathaniel?.currentHP,
                hermesHealth: self.internalHermes?.currentHP,
                hermesMode: self.internalHermes.map { $0.mode == .following ? "following" : "independent" },
                towerCount: self.internalStructureManager?.structures.filter(\.isAlive).count
            )
        }

        public func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
            if let controls = activeOverlayControls() {
                return controls
            }
            var nodes: [GameCommandServer.NodeInfo] = []

            // Add player characters
            if let nathaniel = internalNathaniel {
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
                        "hasCorpse": "\(nathaniel.hasCorpse)",
                    ]
                ))
            }

            if let hermes = internalHermes {
                let frame = hermes.sprite.frame

                // Calculate distance to Nathaniel if in follow mode
                var distanceToTarget: CGFloat = 0
                if let nathaniel = internalNathaniel {
                    distanceToTarget = hermes.position.distance(to: nathaniel.position)
                }

                // Map mode enum to string
                let modeString = switch hermes.mode {
                case .following: "following"
                case .independent: "independent"
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
            if let enemyManager = internalEnemyManager {
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
            if let hud = internalHUD {
                nodes += hud.namedControls(["pauseButton", "characterToggleButton", "followModeButton", "buildButton"])
            }

            return nodes
        }

        public func captureScreenshot() -> Data? {
            captureAsPNG()
        }

        // MARK: - Input Injection

        public func injectTap(at point: CGPoint) -> Bool {
            handlePointerDown(at: point)
        }

        public func injectSwipe(from: CGPoint, to: CGPoint, duration: CGFloat) -> Bool {
            if isBuildMenuVisible {
                _ = handlePointerDown(at: from)
                _ = handlePointerMoved(to: to)
                _ = handlePointerUp(at: to)
                return true
            }
            return self.injectTap(at: to)
        }
    }

#endif
