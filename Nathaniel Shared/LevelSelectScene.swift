import SpriteKit

class LevelSelectScene: SKScene {
    // MARK: - Properties

    /// Title label
    private var titleLabel: SKLabelNode!

    /// Back button
    private var backButton: SKLabelNode!

    /// Level buttons
    private var levelButtons: [SKLabelNode] = []

    /// Survival mode button
    private var survivalButton: SKLabelNode!

    // MARK: - Scene Setup

    class func newLevelSelectScene() -> LevelSelectScene {
        let scene = LevelSelectScene(size: CGSize(width: 1_366, height: 1_024))
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupLevelButtons()
        setupBackButton()

        #if DEBUG
            // Set this scene as the command server delegate
            GameCommandServer.shared.delegate = self
        #endif
    }

    // MARK: - Setup Methods

    private func setupBackground() {
        backgroundColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)
    }

    private func setupTitle() {
        titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "SELECT LEVEL"
        titleLabel.fontSize = 48
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        titleLabel.horizontalAlignmentMode = .center
        addChild(titleLabel)
    }

    private func setupLevelButtons() {
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 100
        let padding: CGFloat = 30

        // Campaign levels (5 levels in a row)
        let campaignLevels = LevelConfig.campaignLevels
        let totalCampaignWidth = CGFloat(campaignLevels.count) * buttonWidth + CGFloat(campaignLevels.count - 1) *
            padding
        let startX = (size.width - totalCampaignWidth) / 2 + buttonWidth / 2

        // Campaign section label
        let campaignLabel = SKLabelNode(fontNamed: "Copperplate")
        campaignLabel.text = "Campaign"
        campaignLabel.fontSize = 28
        campaignLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        campaignLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        campaignLabel.horizontalAlignmentMode = .center
        addChild(campaignLabel)

        // Create level buttons
        for (index, config) in campaignLevels.enumerated() {
            let button = createLevelButton(
                level: config.levelNumber,
                x: startX + CGFloat(index) * (buttonWidth + padding),
                y: size.height * 0.55
            )
            button.name = "level_\(config.levelNumber)"
            addChild(button)
            levelButtons.append(button)
        }

        // Survival mode section
        let survivalLabel = SKLabelNode(fontNamed: "Copperplate")
        survivalLabel.text = "Survival Mode"
        survivalLabel.fontSize = 28
        survivalLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        survivalLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        survivalLabel.horizontalAlignmentMode = .center
        addChild(survivalLabel)

        // Survival button
        survivalButton = createSurvivalButton()
        survivalButton.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        survivalButton.name = "level_0"
        addChild(survivalButton)
    }

    private func createLevelButton(level: Int, x: CGFloat, y: CGFloat) -> SKLabelNode {
        // Create container with background
        let button = SKLabelNode(fontNamed: "Copperplate-Bold")

        // Level name
        let levelName = switch level {
        case 1: "Level 1"
        case 2: "Level 2"
        case 3: "Level 3"
        case 4: "Level 4"
        case 5: "Final"
        default: "Level \(level)"
        }

        // Check if level is completed
        let isCompleted = GameSettings.shared.isLevelCompleted(level)
        let highScore = GameSettings.shared.highScore(forLevel: level)

        button.text = levelName
        button.fontSize = 32
        button.fontColor = isCompleted ? SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0) : .white
        button.position = CGPoint(x: x, y: y)
        button.horizontalAlignmentMode = .center
        button.verticalAlignmentMode = .center

        // Add background
        let background = SKShapeNode(rectOf: CGSize(width: 180, height: 100), cornerRadius: 10)
        if isCompleted {
            background.fillColor = SKColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 1.0)
            background.strokeColor = SKColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)
        } else {
            background.fillColor = SKColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1.0)
            background.strokeColor = SKColor(red: 0.5, green: 0.6, blue: 0.4, alpha: 1.0)
        }
        background.lineWidth = 2
        background.position = .zero
        background.zPosition = -1
        button.addChild(background)

        // Add completion checkmark or high score
        if isCompleted {
            // Checkmark
            let check = SKLabelNode(text: "\u{2713}") // Unicode checkmark
            check.fontSize = 20
            check.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
            check.position = CGPoint(x: 70, y: 20)
            check.zPosition = 1
            button.addChild(check)
        }

        // Show high score if exists
        if let score = highScore {
            let scoreLabel = SKLabelNode(fontNamed: "Copperplate")
            scoreLabel.text = "Best: \(score)"
            scoreLabel.fontSize = 16
            scoreLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
            scoreLabel.position = CGPoint(x: 0, y: -30)
            scoreLabel.horizontalAlignmentMode = .center
            scoreLabel.zPosition = 1
            button.addChild(scoreLabel)
        }

        return button
    }

    private func createSurvivalButton() -> SKLabelNode {
        let button = SKLabelNode(fontNamed: "Copperplate-Bold")
        button.text = "Endless Survival"
        button.fontSize = 32
        button.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0) // Golden color
        button.horizontalAlignmentMode = .center
        button.verticalAlignmentMode = .center

        // Add background with different color
        let background = SKShapeNode(rectOf: CGSize(width: 280, height: 80), cornerRadius: 10)
        background.fillColor = SKColor(red: 0.4, green: 0.35, blue: 0.2, alpha: 1.0)
        background.strokeColor = SKColor(red: 0.7, green: 0.6, blue: 0.3, alpha: 1.0)
        background.lineWidth = 2
        background.position = .zero
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    private func setupBackButton() {
        backButton = SKLabelNode(fontNamed: "Copperplate-Bold")
        backButton.text = "Back"
        backButton.fontSize = 32
        backButton.fontColor = .white
        // Position at bottom center to stay within visible area on all aspect ratios
        backButton.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        backButton.horizontalAlignmentMode = .center
        backButton.name = "backButton"
        addChild(backButton)
    }

    // MARK: - Button Actions

    /// Handle a tap at the given location (used by GameCommandServer)
    func handleTap(at location: CGPoint) {
        handleButtonTap(at: location)
    }

    private func handleButtonTap(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)

        for node in nodesAtPoint {
            guard let nodeName = node.name else { continue }

            if nodeName == "backButton" {
                animateButtonPress(node as? SKLabelNode) {
                    self.goBack()
                }
                return
            }

            if nodeName.hasPrefix("level_") {
                if let levelNum = Int(nodeName.dropFirst(6)) {
                    animateButtonPress(findLevelButton(nodeName)) {
                        self.startLevel(levelNum)
                    }
                }
                return
            }

            // Check if tap was on a button's background
            if let parent = node.parent as? SKLabelNode, let parentName = parent.name {
                if parentName.hasPrefix("level_") {
                    if let levelNum = Int(parentName.dropFirst(6)) {
                        animateButtonPress(parent) {
                            self.startLevel(levelNum)
                        }
                    }
                    return
                }
            }
        }
    }

    private func findLevelButton(_ name: String) -> SKLabelNode? {
        if name == "level_0" {
            return survivalButton
        }
        return levelButtons.first { $0.name == name }
    }

    private func animateButtonPress(_ button: SKLabelNode?, completion: @escaping () -> Void) {
        guard let button else {
            completion()
            return
        }

        let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        let sequence = SKAction.sequence([scaleDown, scaleUp, SKAction.run(completion)])
        button.run(sequence)
    }

    private func startLevel(_ levelNumber: Int) {
        guard let config = LevelConfig.level(levelNumber) else {
            print("Invalid level number: \(levelNumber)")
            return
        }

        let gameScene = GameScene.newGameScene(levelConfig: config)
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(gameScene, transition: transition)
    }

    private func goBack() {
        let mainMenu = MainMenuScene.newMenuScene()
        let transition = SKTransition.fade(withDuration: 0.3)
        view?.presentSceneWithNotification(mainMenu, transition: transition)
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
    extension LevelSelectScene {
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            handleButtonTap(at: location)
        }
    }
#endif

// MARK: - macOS Mouse Handling

#if os(OSX)
    extension LevelSelectScene {
        override func mouseDown(with event: NSEvent) {
            let location = event.location(in: self)
            handleButtonTap(at: location)
        }
    }
#endif
