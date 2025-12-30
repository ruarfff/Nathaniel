#if DEBUG

    import SpriteKit

    extension GameScene: GameCommandDelegate {
        // MARK: - State Queries

        public func getCurrentGameState() -> GameCommandServer.GameState {
            // Determine game status and pause state
            let status: String
            let isPaused: Bool
            let levelInfo = self.findLevelManager()

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
            var nathanielPos: GameCommandServer.PointInfo? = nil
            var hermesPos: GameCommandServer.PointInfo? = nil

            if let nathaniel = findNathaniel() {
                nathanielPos = GameCommandServer.PointInfo(x: nathaniel.position.x, y: nathaniel.position.y)
            }

            if let hermes = findHermes() {
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
                enemyCount: self.findEnemyManager()?.aliveCount ?? 0
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
                        "isAlive": "\(nathaniel.isAlive)",
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
                            "health": "\(enemy.currentHP)/\(enemy.maxHP)",
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
            captureAsPNG()
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
                      let x = Double(xStr), let y = Double(yStr)
                else {
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
                    let aliveEnemies = enemyManager.enemies.filter(\.isAlive)
                    guard index >= 0, index < aliveEnemies.count else {
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
                self.toggleBuildMenu()
                return .success("Build menu \(self.isBuildMenuVisible ? "opened" : "closed")")

            case "restartLevel":
                // Trigger restart via overlay
                return .failure("Restart action not yet implemented")

            case "spawnEnemy":
                guard let typeStr = params?["type"] else {
                    return .failure("Missing type parameter (grunt, soldier, boss)")
                }
                guard let xStr = params?["x"], let yStr = params?["y"],
                      let x = Double(xStr), let y = Double(yStr)
                else {
                    return .failure("Missing x,y parameters")
                }
                guard let enemyManager = findEnemyManager() else {
                    return .failure("Enemy manager not found")
                }

                let position = CGPoint(x: x, y: y)
                let target = self.findNathaniel()

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

            case "buildTower":
                guard let typeStr = params?["type"] else {
                    return .failure("Missing type parameter (gun, laser, heal)")
                }
                guard let hermes = findHermes() else {
                    return .failure("Hermes not found")
                }
                guard let structMgr = findStructureManager() else {
                    return .failure("StructureManager not found")
                }
                // Determine tower type
                let towerType: TowerType
                switch typeStr.lowercased() {
                case "gun", "guntower":
                    towerType = .gunTower
                case "laser", "lasertower":
                    towerType = .laserTower
                case "heal", "healtower":
                    towerType = .healTower
                default:
                    return .failure("Unknown tower type: \(typeStr). Use: gun, laser, or heal")
                }
                // Check affordability
                guard ResourceManager.shared.canAfford(towerType.cost) else {
                    return .failure(
                        "Not enough resources. Need \(towerType.cost), have \(ResourceManager.shared.totalCollected)"
                    )
                }
                // Determine position (near Hermes if not specified)
                let position = if let xStr = params?["x"], let yStr = params?["y"],
                                  let x = Double(xStr), let y = Double(yStr)
                {
                    CGPoint(x: x, y: y)
                } else {
                    // Place 80 pixels to the right of Hermes
                    CGPoint(x: hermes.position.x + 80, y: hermes.position.y)
                }
                // Validate position is within build radius
                guard TowerConfig.isWithinBuildRange(towerPosition: position, hermesPosition: hermes.position) else {
                    return .failure("Position out of build range (max \(TowerConfig.buildRadius) from Hermes)")
                }
                // Spend resources and build
                guard ResourceManager.shared.spendResources(towerType.cost) else {
                    return .failure("Failed to spend resources")
                }
                structMgr.addHermesTower(type: towerType, at: position)
                // Lock Hermes if this is the first tower
                if structMgr.hermesTowerCount == 1 {
                    hermes.lock()
                }
                return .success(
                    "Built \(towerType.displayName) at (\(Int(position.x)), \(Int(position.y))). Towers: \(structMgr.hermesTowerCount)"
                )

            case "releaseHermes":
                guard let hermes = findHermes() else {
                    return .failure("Hermes not found")
                }
                guard let structMgr = findStructureManager() else {
                    return .failure("StructureManager not found")
                }
                let towerCount = structMgr.hermesTowerCount
                guard towerCount > 0 else {
                    return .failure("No towers deployed")
                }
                let recoupAmount = structMgr.destroyAllHermesTowers(camera: self.findCameraNode())
                // Unlock Hermes if locked
                if hermes.mode == .locked {
                    hermes.unlock()
                }
                return .success("Released Hermes. Destroyed \(towerCount) towers, recouped \(recoupAmount) resources")

            case "getTowerInfo":
                guard let structMgr = findStructureManager() else {
                    return .failure("StructureManager not found")
                }
                let count = structMgr.hermesTowerCount
                let recoup = structMgr.potentialRecoupAmount
                return .success("Towers: \(count), potential recoup: \(recoup)")

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
                let modeString = switch hermes.mode {
                case .following: "following"
                case .independent: "independent"
                case .locked: "locked"
                }
                return .success("Hermes mode: \(modeString)")

            case "pause":
                pauseGame()
                return .success("Game paused")

            case "resume":
                resumeGame()
                return .success("Game resumed")

            case "isPaused":
                guard let levelManager = findLevelManager() else {
                    return .failure("Level manager not found")
                }
                return .success("isPaused: \(levelManager.isPaused)")

            case "showPauseMenu":
                pauseGame()
                return .success("Pause menu shown")

            case "hidePauseMenu":
                resumeGame()
                return .success("Pause menu hidden")

            case "pauseMenuIsVisible":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                return .success("pauseMenuIsVisible: \(pauseMenu.isVisible)")

            case "pauseMenuTapResume":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isVisible else {
                    return .failure("Pause menu is not visible")
                }
                pauseMenu.onResume?()
                return .success("Tapped Resume button")

            case "pauseMenuTapSettings":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isVisible else {
                    return .failure("Pause menu is not visible")
                }
                pauseMenu.onSettings?()
                return .success("Tapped Settings button")

            case "pauseMenuTapSaveGame":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isVisible else {
                    return .failure("Pause menu is not visible")
                }
                pauseMenu.onSaveGame?()
                return .success("Tapped Save Game button")

            case "pauseMenuTapExitToMenu":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isVisible else {
                    return .failure("Pause menu is not visible")
                }
                // This shows confirmation dialog
                pauseMenu.showExitConfirmation()
                return .success("Tapped Exit to Menu button (showing confirmation)")

            case "pauseMenuConfirmExit":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isShowingConfirmation else {
                    return .failure("Exit confirmation is not showing")
                }
                pauseMenu.onExitToMenu?()
                return .success("Confirmed exit to menu")

            case "pauseMenuCancelExit":
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isShowingConfirmation else {
                    return .failure("Exit confirmation is not showing")
                }
                pauseMenu.hideConfirmation()
                return .success("Cancelled exit")

            case "exitToMenu":
                // Optional: skipConfirm param to bypass confirmation dialog
                let skipConfirm = params?["skipConfirm"] == "true"
                guard let pauseMenu = findPauseMenu() else {
                    return .failure("Pause menu not found")
                }
                if skipConfirm {
                    // Directly exit without showing confirmation
                    pauseMenu.onExitToMenu?()
                    return .success("Exiting to main menu")
                } else {
                    // Show the pause menu if not visible, then show confirmation
                    if !pauseMenu.isVisible {
                        pauseGame()
                    }
                    pauseMenu.showExitConfirmation()
                    return .success("Exit confirmation shown (tap pauseMenuConfirmExit to confirm)")
                }

        // MARK: - Settings Menu Actions

            case "settingsMenuIsVisible":
                guard let settingsMenu = findSettingsMenu() else {
                    return .failure("Settings menu not found")
                }
                return .success("settingsMenuIsVisible: \(settingsMenu.isVisible)")

            case "openSettings", "showSettingsMenu":
                guard let settingsMenu = findSettingsMenu() else {
                    return .failure("Settings menu not found")
                }
                settingsMenu.show()
                return .success("Settings menu opened")

            case "closeSettings", "hideSettingsMenu":
                guard let settingsMenu = findSettingsMenu() else {
                    return .failure("Settings menu not found")
                }
                settingsMenu.hide()
                return .success("Settings menu closed")

            case "toggleSoundEffects":
                let current = GameSettings.shared.soundEffectsEnabled
                GameSettings.shared.soundEffectsEnabled = !current
                return .success("Sound effects: \(!current)")

            case "toggleMusic":
                let current = GameSettings.shared.musicEnabled
                GameSettings.shared.musicEnabled = !current
                // Apply immediately
                if !current {
                    AudioManager.shared.resumeMusic()
                } else {
                    AudioManager.shared.pauseMusic()
                }
                return .success("Music: \(!current)")

            case "getSoundEffectsEnabled":
                return .success("soundEffectsEnabled: \(GameSettings.shared.soundEffectsEnabled)")

            case "getMusicEnabled":
                return .success("musicEnabled: \(GameSettings.shared.musicEnabled)")

            case "getCurrentSettings", "getSettings":
                let soundEffects = GameSettings.shared.soundEffectsEnabled
                let music = GameSettings.shared.musicEnabled
                return .success("soundEffects: \(soundEffects), music: \(music)")

            case "setSoundEffects":
                guard let valueStr = params?["enabled"], let enabled = Bool(valueStr) else {
                    return .failure("Missing or invalid 'enabled' parameter (true/false)")
                }
                GameSettings.shared.soundEffectsEnabled = enabled
                return .success("Sound effects set to: \(enabled)")

            case "setMusic":
                guard let valueStr = params?["enabled"], let enabled = Bool(valueStr) else {
                    return .failure("Missing or invalid 'enabled' parameter (true/false)")
                }
                GameSettings.shared.musicEnabled = enabled
                if enabled {
                    AudioManager.shared.resumeMusic()
                } else {
                    AudioManager.shared.pauseMusic()
                }
                return .success("Music set to: \(enabled)")

            case "settingsMenuTapBack":
                guard let settingsMenu = findSettingsMenu() else {
                    return .failure("Settings menu not found")
                }
                guard settingsMenu.isVisible else {
                    return .failure("Settings menu is not visible")
                }
                settingsMenu.hide {
                    settingsMenu.onBack?()
                }
                return .success("Tapped Back button")

        // MARK: - Save/Load Actions

            case "saveGame":
                guard let slotIdStr = params?["slot"], let slotId = Int(slotIdStr) else {
                    return .failure("Missing slot parameter (1-3)")
                }
                guard slotId >= 1, slotId <= SaveManager.slotCount else {
                    return .failure("Invalid slot ID: \(slotId). Must be 1-\(SaveManager.slotCount)")
                }
                // Create save state
                let displayName = "Level \(findLevelManager()?.config.levelNumber ?? 1)"
                guard let saveState = createSaveState(displayName: displayName) else {
                    return .failure("Failed to create save state")
                }
                // Save to slot
                let success = SaveManager.shared.saveToSlot(saveState, slotId: slotId)
                if success {
                    return .success("Game saved to slot \(slotId)")
                } else {
                    return .failure("Failed to save to slot \(slotId)")
                }

            case "getSaveSlots":
                let slots = SaveManager.shared.getSaveSlots()
                var slotInfo: [String] = []
                for slot in slots {
                    if slot.hasSave {
                        slotInfo.append("Slot \(slot.id): \(slot.displaySummary)")
                    } else {
                        slotInfo.append("Slot \(slot.id): Empty")
                    }
                }
                return .success(slotInfo.joined(separator: "; "))

            case "hasSaves":
                return .success("hasSaves: \(SaveManager.shared.hasSaves)")

            case "showSaveSlotSelector":
                guard let selector = findSaveSlotSelector() else {
                    return .failure("Save slot selector not found")
                }
                selector.show(mode: .save)
                return .success("Save slot selector shown")

            case "hideSaveSlotSelector":
                guard let selector = findSaveSlotSelector() else {
                    return .failure("Save slot selector not found")
                }
                selector.hide()
                return .success("Save slot selector hidden")

            case "saveSlotSelectorIsVisible":
                guard let selector = findSaveSlotSelector() else {
                    return .failure("Save slot selector not found")
                }
                return .success("saveSlotSelectorIsVisible: \(selector.isVisible)")

            case "deleteSaveSlot":
                guard let slotIdStr = params?["slot"], let slotId = Int(slotIdStr) else {
                    return .failure("Missing slot parameter (1-3)")
                }
                guard slotId >= 1, slotId <= SaveManager.slotCount else {
                    return .failure("Invalid slot ID: \(slotId). Must be 1-\(SaveManager.slotCount)")
                }
                SaveManager.shared.deleteSlot(slotId)
                return .success("Deleted save slot \(slotId)")

            case "deleteAllSaves":
                SaveManager.shared.deleteAllSlots()
                return .success("Deleted all save slots")

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

    // MARK: - Menu Scenes Support

    extension MainMenuScene: GameCommandDelegate {
        public func getCurrentGameState() -> GameCommandServer.GameState {
            GameCommandServer.GameState(
                scene: "MainMenuScene",
                score: 0,
                lives: 0,
                resources: 0,
                elapsedTime: 0,
                gameStatus: "menu",
                isPaused: false,
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
            captureAsPNG()
        }

        public func injectTap(at point: CGPoint) -> Bool {
            // Use frame-based hit testing to find button, then tap at its center
            // This is more reliable than nodes(at:) for SKLabelNodes
            if let buttonName = findButtonAtPoint(point),
               let button = children.first(where: { $0.name == buttonName })
            {
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
            case "continueGame":
                if let button = children.first(where: { $0.name == "continueButton" }) {
                    handleTap(at: button.position)
                    return .success("Continuing game")
                }
                return .failure("Continue button not found (no campaign progress)")
            case "loadGame", "showLoadGameSelector":
                if let button = children.first(where: { $0.name == "loadGameButton" }) {
                    handleTap(at: button.position)
                    return .success("Opening load game selector")
                }
                return .failure("Load Game button not found (no saves)")
            case "hasSaves":
                return .success("hasSaves: \(SaveManager.shared.hasSaves)")
            case "getSaveSlots":
                let slots = SaveManager.shared.getSaveSlots()
                var slotInfo: [String] = []
                for slot in slots {
                    if slot.hasSave {
                        slotInfo.append("Slot \(slot.id): \(slot.displaySummary)")
                    } else {
                        slotInfo.append("Slot \(slot.id): Empty")
                    }
                }
                return .success(slotInfo.joined(separator: "; "))
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
            GameCommandServer.GameState(
                scene: "LevelSelectScene",
                score: 0,
                lives: 0,
                resources: 0,
                elapsedTime: 0,
                gameStatus: "levelSelect",
                isPaused: false,
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
            captureAsPNG()
        }

        public func injectTap(at point: CGPoint) -> Bool {
            // Use frame-based hit testing to find button, then tap at its center
            // This is more reliable than nodes(at:) for SKLabelNodes
            if let buttonName = findButtonAtPoint(point),
               let button = children.first(where: { $0.name == buttonName })
            {
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
            GameCommandServer.GameState(
                scene: "OptionsScene",
                score: 0,
                lives: 0,
                resources: 0,
                elapsedTime: 0,
                gameStatus: "options",
                isPaused: false,
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
            captureAsPNG()
        }

        public func injectTap(at point: CGPoint) -> Bool {
            // Use frame-based hit testing to find button, then tap at its center
            if let buttonName = findButtonAtPoint(point),
               let button = children.first(where: { $0.name == buttonName })
            {
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
            GameCommandServer.GameState(
                scene: "CreditsScene",
                score: 0,
                lives: 0,
                resources: 0,
                elapsedTime: 0,
                gameStatus: "credits",
                isPaused: false,
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
            captureAsPNG()
        }

        public func injectTap(at point: CGPoint) -> Bool {
            // Use frame-based hit testing to find button, then tap at its center
            if let buttonName = findButtonAtPoint(point),
               let button = children.first(where: { $0.name == buttonName })
            {
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
