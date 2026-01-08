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
        setupCornerSprites()
        setupBottomDecoration()
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
        // Pure black background for arcade aesthetic
        backgroundColor = SKColor.black
    }

    private func setupCornerSprites() {
        let margin: CGFloat = 80
        let spriteScale: CGFloat = 2.0 // Scale up pixel art for visibility

        // Top-left: Boss/Mech sprite (first frame from boss1spritesheet)
        // Boss sheet is 600x642, appears to be ~5 columns x 5 rows
        if let topLeftSprite = extractSpriteFrame(
            from: "boss1spritesheet",
            frameSize: CGSize(width: 120, height: 128),
            row: 0,
            column: 0
        ) {
            let sprite = SKSpriteNode(texture: topLeftSprite)
            sprite.setScale(spriteScale * 0.6)
            sprite.position = CGPoint(x: margin, y: size.height - margin)
            sprite.zPosition = 5
            addChild(sprite)
            addFloatingAnimation(to: sprite)
        }

        // Top-right: Nathaniel sprite (first frame)
        // Nathaniel sheet is 201x70, appears to be 3 frames at ~67x70
        if let topRightSprite = extractSpriteFrame(
            from: "nathanielspritesheet",
            frameSize: CGSize(width: 67, height: 70),
            row: 0,
            column: 0
        ) {
            let sprite = SKSpriteNode(texture: topRightSprite)
            sprite.setScale(spriteScale)
            sprite.position = CGPoint(x: size.width - margin, y: size.height - margin)
            sprite.zPosition = 5
            addChild(sprite)
            addFloatingAnimation(to: sprite)
        }

        // Bottom-left: Grunt enemy sprite (first frame)
        // Grunt sheet is 280x80, appears to be 4 frames at ~70x80
        if let bottomLeftSprite = extractSpriteFrame(
            from: "gruntspritesheet",
            frameSize: CGSize(width: 70, height: 80),
            row: 0,
            column: 0
        ) {
            let sprite = SKSpriteNode(texture: bottomLeftSprite)
            sprite.setScale(spriteScale)
            sprite.position = CGPoint(x: margin, y: margin + 40)
            sprite.zPosition = 5
            addChild(sprite)
            addFloatingAnimation(to: sprite)
        }

        // Bottom-right: Hermes sprite (first frame from idle sheet)
        // Hermes sheet is 260x35, appears to be ~5 frames at 52x35
        if let bottomRightSprite = extractSpriteFrame(
            from: "hermesidlespritesheet",
            frameSize: CGSize(width: 52, height: 35),
            row: 0,
            column: 0
        ) {
            let sprite = SKSpriteNode(texture: bottomRightSprite)
            sprite.setScale(spriteScale * 2.0) // Hermes is small, scale up more
            sprite.position = CGPoint(x: size.width - margin, y: margin + 40)
            sprite.zPosition = 5
            addChild(sprite)
            addFloatingAnimation(to: sprite)
        }
    }

    private func extractSpriteFrame(
        from sheetName: String,
        frameSize: CGSize,
        row: Int,
        column: Int
    ) -> SKTexture? {
        let texture = SKTexture(imageNamed: sheetName)

        // Check if texture loaded (size will be zero if not found)
        let sheetWidth = texture.size().width
        let sheetHeight = texture.size().height

        guard sheetWidth > 0, sheetHeight > 0 else {
            return nil
        }

        // Calculate normalized coordinates (0-1 range, origin at bottom-left in SpriteKit)
        let x = CGFloat(column) * frameSize.width / sheetWidth
        let y = 1.0 - (CGFloat(row + 1) * frameSize.height / sheetHeight)
        let width = frameSize.width / sheetWidth
        let height = frameSize.height / sheetHeight

        let rect = CGRect(x: x, y: y, width: width, height: height)
        return SKTexture(rect: rect, in: texture)
    }

    private func addFloatingAnimation(to sprite: SKSpriteNode) {
        let moveUp = SKAction.moveBy(x: 0, y: 8, duration: 1.5)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let float = SKAction.sequence([moveUp, moveDown])
        sprite.run(SKAction.repeatForever(float))
    }

    private func setupBottomDecoration() {
        // Create crossed arrows/lines decoration at bottom center
        let decorationContainer = SKNode()
        decorationContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.06)
        decorationContainer.zPosition = 5

        let lineColor = SKColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 0.8)

        // Left diagonal line
        let leftLine = SKShapeNode()
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: -60, y: 0))
        leftPath.addLine(to: CGPoint(x: -20, y: 15))
        leftLine.path = leftPath
        leftLine.strokeColor = lineColor
        leftLine.lineWidth = 3
        decorationContainer.addChild(leftLine)

        // Right diagonal line (mirrored)
        let rightLine = SKShapeNode()
        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: 60, y: 0))
        rightPath.addLine(to: CGPoint(x: 20, y: 15))
        rightLine.path = rightPath
        rightLine.strokeColor = lineColor
        rightLine.lineWidth = 3
        decorationContainer.addChild(rightLine)

        // Center crossing lines (V shape pointing down)
        let centerV = SKShapeNode()
        let centerPath = CGMutablePath()
        centerPath.move(to: CGPoint(x: -25, y: 10))
        centerPath.addLine(to: CGPoint(x: 0, y: -5))
        centerPath.addLine(to: CGPoint(x: 25, y: 10))
        centerV.path = centerPath
        centerV.strokeColor = lineColor
        centerV.lineWidth = 3
        decorationContainer.addChild(centerV)

        // Small decorative dots
        for xOffset in [-40, -15, 15, 40] as [CGFloat] {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = lineColor
            dot.strokeColor = .clear
            dot.position = CGPoint(x: xOffset, y: -8)
            decorationContainer.addChild(dot)
        }

        addChild(decorationContainer)
    }

    private func setupTitle() {
        // Blue sci-fi color for arcade aesthetic
        let titleBlue = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

        // Shadow label (behind main title for depth)
        let shadowLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        shadowLabel.text = "NATHANIEL"
        shadowLabel.fontSize = 80
        shadowLabel.fontColor = SKColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 0.8)
        shadowLabel.position = CGPoint(x: size.width / 2 + 4, y: size.height * 0.85 - 4)
        shadowLabel.horizontalAlignmentMode = .center
        shadowLabel.zPosition = -1
        addChild(shadowLabel)

        // Main title with glow effect
        let glowContainer = SKEffectNode()
        glowContainer.shouldRasterize = true
        glowContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        glowContainer.zPosition = 1

        // Add blur filter for glow
        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(3.0, forKey: kCIInputRadiusKey)
        glowContainer.filter = blur

        // Glow label (slightly larger, more transparent)
        let glowLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        glowLabel.text = "NATHANIEL"
        glowLabel.fontSize = 80
        glowLabel.fontColor = titleBlue.withAlphaComponent(0.6)
        glowLabel.horizontalAlignmentMode = .center
        glowContainer.addChild(glowLabel)
        addChild(glowContainer)

        // Main title (crisp, on top)
        titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "NATHANIEL"
        titleLabel.fontSize = 80
        titleLabel.fontColor = titleBlue
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 2
        addChild(titleLabel)

        // Subtle pulse animation on main title
        let scaleUp = SKAction.scale(to: 1.02, duration: 2.0)
        let scaleDown = SKAction.scale(to: 1.0, duration: 2.0)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        titleLabel.run(SKAction.repeatForever(pulse))
    }

    private func setupMenuButtons() {
        let buttonSpacing: CGFloat = 60
        var currentY = size.height * 0.58

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
