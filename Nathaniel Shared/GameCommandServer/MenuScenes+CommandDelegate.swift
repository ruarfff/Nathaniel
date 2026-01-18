#if DEBUG

//
    //  MenuScenes+CommandDelegate.swift
    //  Nathaniel Shared
//
    //  GameCommandDelegate implementations for menu scenes.
//

    import SpriteKit

    // MARK: - MainMenuScene

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

    // MARK: - LevelSelectScene

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

    // MARK: - OptionsScene

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

    // MARK: - CreditsScene

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
