import SpriteKit

class MainMenuScene: SKScene {
    // MARK: - Properties

    /// Title label
    private var titleLabel: SKLabelNode!

    /// Menu buttons
    private var continueButton: SKLabelNode?
    private var loadGameButton: SKLabelNode?
    private var startButton: SKLabelNode!
    private var optionsButton: SKLabelNode!
    private var creditsButton: SKLabelNode!

    /// Save slot selector for loading games
    private var saveSlotSelector: SaveSlotSelector?

    /// Background node
    private var backgroundNode: SKSpriteNode?

    // MARK: - Scene Setup

    class func newMenuScene() -> MainMenuScene {
        let scene = MainMenuScene(size: CGSize(width: 1_366, height: 1_024))
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupMenuButtons()
        setupSaveSlotSelector()

        // Start menu music
        AudioManager.shared.playMusic(.menu)

        #if DEBUG
            // Set this scene as the command server delegate
            GameCommandServer.shared.delegate = self
        #endif
    }

    // MARK: - Setup Methods

    private func setupBackground() {
        // Dark green gradient-like background to match game aesthetic
        backgroundColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)

        // Add some decorative elements
        let pattern = createGrassPattern()
        pattern.position = CGPoint(x: size.width / 2, y: size.height / 4)
        addChild(pattern)
    }

    private func createGrassPattern() -> SKNode {
        let container = SKNode()

        // Create a simple decorative pattern at the bottom
        let grassColor = SKColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.5)

        for i in 0 ..< 20 {
            let grass = SKShapeNode(rectOf: CGSize(width: 60, height: 8))
            grass.fillColor = grassColor
            grass.strokeColor = .clear
            grass.position = CGPoint(
                x: CGFloat(i - 10) * 70,
                y: CGFloat.random(in: -20 ... 20)
            )
            container.addChild(grass)
        }

        return container
    }

    private func setupTitle() {
        // Main title
        titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "NATHANIEL"
        titleLabel.fontSize = 72
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0) // Gold-ish
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        titleLabel.horizontalAlignmentMode = .center
        addChild(titleLabel)

        // Subtitle
        let subtitleLabel = SKLabelNode(fontNamed: "Copperplate")
        subtitleLabel.text = "Defender of Earth"
        subtitleLabel.fontSize = 28
        subtitleLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7 - 50)
        subtitleLabel.horizontalAlignmentMode = .center
        addChild(subtitleLabel)

        // Animate title
        let scaleUp = SKAction.scale(to: 1.05, duration: 1.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 1.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        titleLabel.run(SKAction.repeatForever(pulse))
    }

    private func setupMenuButtons() {
        let buttonSpacing: CGFloat = 70
        var currentY = size.height * 0.45

        // Continue button (only if there's saved campaign progress)
        if GameSettings.shared.hasSavedProgress {
            let continueLevel = GameSettings.shared.continueLevel
            continueButton = createMenuButton(text: "Continue (Level \(continueLevel))", yPosition: currentY)
            continueButton?.name = "continueButton"
            continueButton?.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0) // Green highlight
            addChild(continueButton!)
            currentY -= buttonSpacing
        }

        // Load Game button (only if there are mid-level saves)
        if SaveManager.shared.hasSaves {
            loadGameButton = createMenuButton(text: "Load Game", yPosition: currentY)
            loadGameButton?.name = "loadGameButton"
            loadGameButton?.fontColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0) // Blue highlight
            addChild(loadGameButton!)
            currentY -= buttonSpacing
        }

        // Start Game button (now goes to level select or new game)
        startButton = createMenuButton(text: "Level Select", yPosition: currentY)
        startButton.name = "startButton"
        addChild(startButton)
        currentY -= buttonSpacing

        // Options button
        optionsButton = createMenuButton(text: "Options", yPosition: currentY)
        optionsButton.name = "optionsButton"
        addChild(optionsButton)
        currentY -= buttonSpacing

        // Credits button
        creditsButton = createMenuButton(text: "Credits", yPosition: currentY)
        creditsButton.name = "creditsButton"
        addChild(creditsButton)
    }

    private func setupSaveSlotSelector() {
        let selector = SaveSlotSelector(size: size)
        selector.zPosition = 1_000 // Above everything else
        // Position at center of scene (SaveSlotSelector is centered at origin)
        selector.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(selector)
        saveSlotSelector = selector

        // Set up callbacks
        selector.onSlotSelected = { [weak self] slotId in
            self?.loadGameFromSlot(slotId)
        }

        selector.onCancel = {
            // Just close the selector, stay on main menu
            print("[MainMenuScene] Load cancelled")
        }
    }

    private func createMenuButton(text: String, yPosition: CGFloat) -> SKLabelNode {
        let button = SKLabelNode(fontNamed: "Copperplate-Bold")
        button.text = text
        button.fontSize = 36
        button.fontColor = .white
        button.position = CGPoint(x: size.width / 2, y: yPosition)
        button.horizontalAlignmentMode = .center

        return button
    }

    // MARK: - Button Actions

    /// Handle a tap at the given location (used by GameCommandServer)
    func handleTap(at location: CGPoint) {
        handleButtonTap(at: location)
    }

    private func handleButtonTap(at location: CGPoint) {
        // Check if save slot selector handles the touch first
        if let selector = saveSlotSelector, selector.isVisible {
            _ = selector.handleTouch(at: location)
            return
        }

        let nodesAtPoint = nodes(at: location)

        for node in nodesAtPoint {
            guard let nodeName = node.name else { continue }

            switch nodeName {
            case "continueButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.continueGame()
                }
            case "loadGameButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.showLoadGameSelector()
                }
            case "startButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.startGame()
                }
            case "optionsButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.showOptions()
                }
            case "creditsButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.showCredits()
                }
            default:
                break
            }
        }
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

    private func continueGame() {
        // Get the next level to play based on saved progress
        let continueLevel = GameSettings.shared.continueLevel
        guard let levelConfig = LevelConfig.level(continueLevel) else {
            // If invalid, just go to level select
            startGame()
            return
        }

        let gameScene = GameScene.newGameScene(levelConfig: levelConfig)
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(gameScene, transition: transition)
    }

    private func startGame() {
        let levelSelectScene = LevelSelectScene.newLevelSelectScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(levelSelectScene, transition: transition)
    }

    private func showOptions() {
        let optionsScene = OptionsScene.newOptionsScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(optionsScene, transition: transition)
    }

    private func showCredits() {
        let creditsScene = CreditsScene.newCreditsScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(creditsScene, transition: transition)
    }

    private func showLoadGameSelector() {
        saveSlotSelector?.show(mode: .load)
    }

    private func loadGameFromSlot(_ slotId: Int) {
        guard let savedState = SaveManager.shared.loadFromSlot(slotId) else {
            print("[MainMenuScene] Failed to load save from slot \(slotId)")
            return
        }

        // Create game scene from saved state
        let gameScene = GameScene.newGameScene(fromSave: savedState)

        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(gameScene, transition: transition)
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
    extension MainMenuScene {
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            handleButtonTap(at: location)
        }
    }
#endif

// MARK: - macOS Mouse Handling

#if os(OSX)
    extension MainMenuScene {
        override func mouseDown(with event: NSEvent) {
            let location = event.location(in: self)
            handleButtonTap(at: location)
        }
    }
#endif
