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
            if let selector = children.compactMap({ $0 as? SaveSlotSelector }).first, selector.isVisible {
                return selector.namedControls(["slot_1", "slot_2", "slot_3", "cancelButton"])
            }
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
            if let selector = children.compactMap({ $0 as? SaveSlotSelector }).first, selector.isVisible {
                handleTap(at: point)
            } else if let buttonName = findButtonAtPoint(point),
                      let button = children.first(where: { $0.name == buttonName })
            {
                handleTap(at: button.position)
            } else {
                handleTap(at: point)
            }
            return true
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
    }

#endif
