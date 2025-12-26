//
//  GameScene+CommandDelegate.swift
//  Nathaniel Shared
//
//  Extension to make GameScene conform to GameCommandDelegate for agent testing.
//  Only compiled in DEBUG builds.
//

#if DEBUG

import SpriteKit

extension GameScene: GameCommandDelegate {

    // MARK: - State Queries

    public func getCurrentGameState() -> GameCommandServer.GameState {
        // Determine game status
        let status: String
        if let overlay = children.first(where: { $0 is GameOverlay }) as? GameOverlay {
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
        }

        // Get player positions
        var nathanielPos: GameCommandServer.PointInfo? = nil
        var hermesPos: GameCommandServer.PointInfo? = nil

        if let nathaniel = findNathaniel() {
            nathanielPos = GameCommandServer.PointInfo(x: nathaniel.position.x, y: nathaniel.position.y)
        }

        if let hermes = findHermes() {
            hermesPos = GameCommandServer.PointInfo(x: hermes.position.x, y: hermes.position.y)
        }

        // Get level manager info
        let levelInfo = findLevelManager()

        return GameCommandServer.GameState(
            scene: "GameScene",
            score: levelInfo?.score ?? 0,
            lives: levelInfo?.lives ?? 0,
            resources: ResourceManager.shared.totalCollected,
            elapsedTime: levelInfo?.elapsedTime ?? 0,
            gameStatus: status,
            playerPosition: nathanielPos,
            hermesPosition: hermesPos,
            enemyCount: findEnemyManager()?.aliveCount ?? 0
        )
    }

    public func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
        var nodes: [GameCommandServer.NodeInfo] = []

        // Add player characters
        if let nathaniel = findNathaniel() {
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
                    "isAlive": "\(nathaniel.isAlive)"
                ]
            ))
        }

        if let hermes = findHermes() {
            let frame = hermes.sprite.frame
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
                    "isInBuildMode": "\(hermes.isInBuildMode)"
                ]
            ))
        }

        // Add enemies
        if let enemyManager = findEnemyManager() {
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
                        "health": "\(enemy.currentHP)/\(enemy.maxHP)"
                    ]
                ))
            }
        }

        // Add HUD elements
        if let hud = findHUD() {
            nodes.append(hud.toNodeInfo(interactive: true, properties: ["type": "HUD"]))
        }

        return nodes
    }

    public func captureScreenshot() -> Data? {
        return captureAsPNG()
    }

    // MARK: - Input Injection

    public func injectTap(at point: CGPoint) -> Bool {
        // Use the existing handleTap method
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
        switch name {
        case "selectNathaniel":
            if let nathaniel = findNathaniel() {
                handleTap(at: nathaniel.position)
                return .success("Selected Nathaniel")
            }
            return .failure("Nathaniel not found")

        case "selectHermes":
            if let hermes = findHermes() {
                handleTap(at: hermes.position)
                return .success("Selected Hermes")
            }
            return .failure("Hermes not found")

        case "moveNathaniel":
            guard let xStr = params?["x"], let yStr = params?["y"],
                  let x = Double(xStr), let y = Double(yStr) else {
                return .failure("Missing x,y parameters")
            }
            let point = CGPoint(x: x, y: y)
            handleMoveCommand(to: point)
            return .success("Moving Nathaniel to (\(x), \(y))")

        case "targetEnemy":
            guard let indexStr = params?["index"], let index = Int(indexStr) else {
                return .failure("Missing index parameter")
            }
            if let enemyManager = findEnemyManager() {
                let aliveEnemies = enemyManager.enemies.filter { $0.isAlive }
                guard index >= 0 && index < aliveEnemies.count else {
                    return .failure("Invalid enemy index")
                }
                let enemy = aliveEnemies[index]
                handleTap(at: enemy.position)
                return .success("Targeted enemy \(index)")
            }
            return .failure("Enemy manager not found")

        case "toggleBuildMenu":
            // Simulate tapping the build button
            return .failure("Build menu action not yet implemented")

        case "restartLevel":
            // Trigger restart via overlay
            return .failure("Restart action not yet implemented")

        default:
            return .failure("Unknown action: \(name)")
        }
    }

    // MARK: - Helper Methods (find private properties)

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
}

// MARK: - Menu Scenes Support

extension MainMenuScene: GameCommandDelegate {

    public func getCurrentGameState() -> GameCommandServer.GameState {
        return GameCommandServer.GameState(
            scene: "MainMenuScene",
            score: 0,
            lives: 0,
            resources: 0,
            elapsedTime: 0,
            gameStatus: "menu",
            playerPosition: nil,
            hermesPosition: nil,
            enemyCount: 0
        )
    }

    public func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
        var nodes: [GameCommandServer.NodeInfo] = []

        // Find all labeled button nodes
        for child in children {
            if let label = child as? SKLabelNode, let name = label.name {
                nodes.append(GameCommandServer.NodeInfo(
                    name: name,
                    type: "Button",
                    frame: GameCommandServer.FrameInfo(
                        x: label.frame.origin.x,
                        y: label.frame.origin.y,
                        width: label.frame.size.width,
                        height: label.frame.size.height
                    ),
                    interactive: true,
                    properties: ["text": label.text ?? ""]
                ))
            }
        }

        return nodes
    }

    public func captureScreenshot() -> Data? {
        return captureAsPNG()
    }

    public func injectTap(at point: CGPoint) -> Bool {
        handleTap(at: point)
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        switch name {
        case "startGame":
            handleTap(at: findButtonCenter(named: "startButton") ?? CGPoint(x: size.width/2, y: size.height*0.45))
            return .success("Starting game")
        case "options":
            handleTap(at: findButtonCenter(named: "optionsButton") ?? CGPoint(x: size.width/2, y: size.height*0.35))
            return .success("Opening options")
        case "credits":
            handleTap(at: findButtonCenter(named: "creditsButton") ?? CGPoint(x: size.width/2, y: size.height*0.25))
            return .success("Opening credits")
        default:
            return .failure("Unknown action: \(name)")
        }
    }

    private func findButtonCenter(named name: String) -> CGPoint? {
        for child in children {
            if child.name == name {
                return child.position
            }
        }
        return nil
    }
}

extension LevelSelectScene: GameCommandDelegate {

    public func getCurrentGameState() -> GameCommandServer.GameState {
        return GameCommandServer.GameState(
            scene: "LevelSelectScene",
            score: 0,
            lives: 0,
            resources: 0,
            elapsedTime: 0,
            gameStatus: "levelSelect",
            playerPosition: nil,
            hermesPosition: nil,
            enemyCount: 0
        )
    }

    public func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
        var nodes: [GameCommandServer.NodeInfo] = []

        func addNode(_ node: SKNode) {
            if let label = node as? SKLabelNode, let name = label.name {
                nodes.append(GameCommandServer.NodeInfo(
                    name: name,
                    type: "Button",
                    frame: GameCommandServer.FrameInfo(
                        x: label.frame.origin.x,
                        y: label.frame.origin.y,
                        width: label.frame.size.width,
                        height: label.frame.size.height
                    ),
                    interactive: true,
                    properties: ["text": label.text ?? ""]
                ))
            }
        }

        for child in children {
            addNode(child)
        }

        return nodes
    }

    public func captureScreenshot() -> Data? {
        return captureAsPNG()
    }

    public func injectTap(at point: CGPoint) -> Bool {
        handleTap(at: point)
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        if name.hasPrefix("level_") {
            if let levelNum = Int(name.dropFirst(6)) {
                // Find the level button and tap it
                for child in children {
                    if child.name == name {
                        handleTap(at: child.position)
                        return .success("Starting level \(levelNum)")
                    }
                }
            }
        }

        switch name {
        case "back":
            for child in children {
                if child.name == "backButton" {
                    handleTap(at: child.position)
                    return .success("Going back")
                }
            }
            return .failure("Back button not found")
        default:
            return .failure("Unknown action: \(name)")
        }
    }
}

#endif
