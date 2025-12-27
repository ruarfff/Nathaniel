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

            // Calculate distance to Nathaniel if in follow mode
            var distanceToTarget: CGFloat = 0
            if let nathaniel = findNathaniel() {
                let dx = nathaniel.position.x - hermes.position.x
                let dy = nathaniel.position.y - hermes.position.y
                distanceToTarget = sqrt(dx * dx + dy * dy)
            }

            // Map mode enum to string
            let modeString: String
            switch hermes.mode {
            case .following: modeString = "following"
            case .independent: modeString = "independent"
            case .locked: modeString = "locked"
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
                    "distanceToTarget": String(format: "%.1f", distanceToTarget)
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

        case "toggleCharacter":
            // Use the new toggleSelectedCharacter method
            toggleSelectedCharacter()
            return .success("Toggled character selection")

        case "toggleBuildMenu":
            // Simulate tapping the build button
            return .failure("Build menu action not yet implemented")

        case "restartLevel":
            // Trigger restart via overlay
            return .failure("Restart action not yet implemented")

        case "spawnEnemy":
            guard let typeStr = params?["type"] else {
                return .failure("Missing type parameter (grunt, soldier, boss)")
            }
            guard let xStr = params?["x"], let yStr = params?["y"],
                  let x = Double(xStr), let y = Double(yStr) else {
                return .failure("Missing x,y parameters")
            }
            guard let enemyManager = findEnemyManager() else {
                return .failure("Enemy manager not found")
            }

            let position = CGPoint(x: x, y: y)
            let target = findNathaniel()

            // Spawn the appropriate enemy type
            switch typeStr.lowercased() {
            case "grunt", "gr":
                enemyManager.addEnemy(name: "Grunt", at: position, target: target)
                return .success("Spawned Grunt at (\(x), \(y))")
            case "soldier", "so":
                enemyManager.addEnemy(name: "Soldier", at: position, target: target)
                return .success("Spawned Soldier at (\(x), \(y))")
            case "boss", "bo":
                enemyManager.addEnemy(name: "Boss", at: position, target: target)
                return .success("Spawned Boss at (\(x), \(y))")
            default:
                return .failure("Unknown enemy type: \(typeStr). Use: grunt, soldier, or boss")
            }

        case "killAllEnemies":
            guard let enemyManager = findEnemyManager() else {
                return .failure("Enemy manager not found")
            }
            let count = enemyManager.aliveCount
            for enemy in enemyManager.enemies where enemy.isAlive {
                enemy.currentHP = 0
            }
            return .success("Killed \(count) enemies")

        case "healPlayer":
            if let nathaniel = findNathaniel() {
                nathaniel.currentHP = nathaniel.maxHP
                nathaniel.updateHealthBar()
            }
            if let hermes = findHermes() {
                hermes.currentHP = hermes.maxHP
                hermes.updateHealthBar()
            }
            return .success("Healed all players to full health")

        case "addResources":
            guard let amountStr = params?["amount"], let amount = Int(amountStr) else {
                return .failure("Missing amount parameter")
            }
            ResourceManager.shared.addResources(amount)
            return .success("Added \(amount) resources")

        case "setHermesMode":
            guard let modeStr = params?["mode"] else {
                return .failure("Missing mode parameter (following, independent)")
            }
            guard let hermes = findHermes() else {
                return .failure("Hermes not found")
            }
            // Can't change mode while locked
            guard hermes.mode != .locked else {
                return .failure("Cannot change mode while Hermes is locked (towers deployed)")
            }
            switch modeStr.lowercased() {
            case "following", "follow":
                hermes.enterFollowMode()
                return .success("Hermes set to following mode")
            case "independent", "build":
                hermes.enterIndependentMode()
                return .success("Hermes set to independent mode")
            default:
                return .failure("Unknown mode: \(modeStr). Use: following or independent")
            }

        case "toggleHermesFollow":
            guard let hermes = findHermes() else {
                return .failure("Hermes not found")
            }
            guard hermes.mode != .locked else {
                return .failure("Cannot toggle mode while Hermes is locked (towers deployed)")
            }
            hermes.toggleMode()
            let newMode = hermes.mode == .following ? "following" : "independent"
            return .success("Hermes mode toggled to \(newMode)")

        case "getHermesMode":
            guard let hermes = findHermes() else {
                return .failure("Hermes not found")
            }
            let modeString: String
            switch hermes.mode {
            case .following: modeString = "following"
            case .independent: modeString = "independent"
            case .locked: modeString = "locked"
            }
            return .success("Hermes mode: \(modeString)")

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
        // Use frame-based hit testing to find button, then tap at its center
        // This is more reliable than nodes(at:) for SKLabelNodes
        if let buttonName = findButtonAtPoint(point),
           let button = children.first(where: { $0.name == buttonName }) {
            handleTap(at: button.position)
        } else {
            handleTap(at: point)
        }
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        switch name {
        case "startGame":
            if let button = children.first(where: { $0.name == "startButton" }) {
                handleTap(at: button.position)
                return .success("Starting game")
            }
            return .failure("Start button not found")
        case "options":
            if let button = children.first(where: { $0.name == "optionsButton" }) {
                handleTap(at: button.position)
                return .success("Opening options")
            }
            return .failure("Options button not found")
        case "credits":
            if let button = children.first(where: { $0.name == "creditsButton" }) {
                handleTap(at: button.position)
                return .success("Opening credits")
            }
            return .failure("Credits button not found")
        default:
            return .failure("Unknown action: \(name)")
        }
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
        // Use frame-based hit testing to find button, then tap at its center
        // This is more reliable than nodes(at:) for SKLabelNodes
        if let buttonName = findButtonAtPoint(point),
           let button = children.first(where: { $0.name == buttonName }) {
            handleTap(at: button.position)
        } else {
            handleTap(at: point)
        }
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        if name.hasPrefix("level_") {
            if let levelNum = Int(name.dropFirst(6)) {
                // Find the level button and tap it
                if let button = children.first(where: { $0.name == name }) {
                    handleTap(at: button.position)
                    return .success("Starting level \(levelNum)")
                }
                return .failure("Level \(levelNum) button not found")
            }
        }

        switch name {
        case "back":
            if let button = children.first(where: { $0.name == "backButton" }) {
                handleTap(at: button.position)
                return .success("Going back")
            }
            return .failure("Back button not found")
        default:
            return .failure("Unknown action: \(name)")
        }
    }
}

// MARK: - OptionsScene Support

extension OptionsScene: GameCommandDelegate {

    public func getCurrentGameState() -> GameCommandServer.GameState {
        return GameCommandServer.GameState(
            scene: "OptionsScene",
            score: 0,
            lives: 0,
            resources: 0,
            elapsedTime: 0,
            gameStatus: "options",
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
        // Use frame-based hit testing to find button, then tap at its center
        if let buttonName = findButtonAtPoint(point),
           let button = children.first(where: { $0.name == buttonName }) {
            handleTap(at: button.position)
        } else {
            handleTap(at: point)
        }
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        switch name {
        case "back":
            if let button = children.first(where: { $0.name == "backButton" }) {
                handleTap(at: button.position)
                return .success("Going back to menu")
            }
            return .failure("Back button not found")
        case "toggleSound":
            if let button = children.first(where: { $0.name == "soundToggle" }) {
                handleTap(at: button.position)
                return .success("Toggled sound effects")
            }
            return .failure("Sound toggle not found")
        case "toggleMusic":
            if let button = children.first(where: { $0.name == "musicToggle" }) {
                handleTap(at: button.position)
                return .success("Toggled music")
            }
            return .failure("Music toggle not found")
        default:
            return .failure("Unknown action: \(name)")
        }
    }
}

// MARK: - CreditsScene Support

extension CreditsScene: GameCommandDelegate {

    public func getCurrentGameState() -> GameCommandServer.GameState {
        return GameCommandServer.GameState(
            scene: "CreditsScene",
            score: 0,
            lives: 0,
            resources: 0,
            elapsedTime: 0,
            gameStatus: "credits",
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
        // Use frame-based hit testing to find button, then tap at its center
        if let buttonName = findButtonAtPoint(point),
           let button = children.first(where: { $0.name == buttonName }) {
            handleTap(at: button.position)
        } else {
            handleTap(at: point)
        }
        return true
    }

    public func executeAction(name: String, params: [String: String]?) -> ActionResult {
        switch name {
        case "back":
            if let button = children.first(where: { $0.name == "backButton" }) {
                handleTap(at: button.position)
                return .success("Going back to menu")
            }
            return .failure("Back button not found")
        default:
            return .failure("Unknown action: \(name)")
        }
    }
}

#endif
