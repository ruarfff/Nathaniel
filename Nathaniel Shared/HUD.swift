import SpriteKit

// MARK: - Safe Area Insets

/// Cross-platform struct for safe area insets (in scene coordinates)
struct HUDSafeAreaInsets {
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat

    static let zero = HUDSafeAreaInsets(top: 0, bottom: 0, left: 0, right: 0)

    init(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

// MARK: - HUD

/// Heads-up display overlay showing game status
class HUD: SKNode {
    // MARK: - Properties

    /// Size of the viewport (visible area in scene coordinates)
    private let viewportSize: CGSize

    /// Safe area insets (in scene coordinates, already scaled)
    private let safeInsets: HUDSafeAreaInsets

    /// Container for top-left info (lives, score, resources)
    private let topLeftContainer: SKNode

    /// Container for bottom info (selected character)
    private let bottomContainer: SKNode

    /// Lives display
    private let livesLabel: SKLabelNode
    private var livesIcons: [SKSpriteNode] = []

    /// Score display
    private let scoreLabel: SKLabelNode
    private let scoreValueLabel: SKLabelNode
    private var cachedScore: Int = -1

    /// Resources display
    private let resourcesLabel: SKLabelNode
    private let resourcesValueLabel: SKLabelNode
    private var cachedResources: Int = -1

    /// Selected character indicator
    private let selectedLabel: SKLabelNode
    private let selectedCharacterLabel: SKLabelNode

    /// Timer display
    private let timerLabel: SKLabelNode

    /// Release Hermes button (visible when Hermes has deployed towers)
    private var releaseHermesButton: SKNode?
    private let releaseButtonName = "releaseHermesButton"

    /// Callback when Release Hermes button is tapped
    var onReleaseHermes: (() -> Void)?

    /// Build button (visible when Hermes is selected)
    private var buildButton: SKNode?
    private let buildButtonName = "buildButton"

    /// Tower count label (visible when Hermes has towers)
    private var towerCountLabel: SKLabelNode?

    /// Callback when Build button is tapped
    var onBuildTapped: (() -> Void)?

    /// Character toggle button (always visible)
    private var characterToggleButton: SKNode?
    private let toggleButtonName = "characterToggleButton"

    /// Callback when character toggle button is tapped
    var onCharacterToggle: (() -> Void)?

    /// Hermes follow mode toggle button (visible when Nathaniel is selected)
    private var followModeButton: SKNode?
    private let followButtonName = "followModeButton"
    private var followModeIcon: SKLabelNode?

    /// Callback when follow mode button is tapped
    var onFollowModeToggle: (() -> Void)?

    /// Whether Hermes is currently in follow mode
    private var isHermesFollowing: Bool = false

    /// Whether Hermes is currently selected (controls build button visibility)
    private var isHermesSelected: Bool = false

    /// Pause button (always visible during gameplay)
    private var pauseButton: SKNode?
    private let pauseButtonName = "pauseButton"

    /// Callback when pause button is tapped
    var onPauseTapped: (() -> Void)?

    /// Padding from screen edges
    private let padding: CGFloat = 16

    /// Spacing between elements
    private let spacing: CGFloat = 8

    // MARK: - Player Health Display

    /// Container for player health bars (bottom-left)
    private var playerHealthContainer: SKNode?

    /// Nathaniel health bar components
    private var nathanielHealthBar: SKShapeNode?
    private var nathanielHealthFill: SKShapeNode?
    private var nathanielNameLabel: SKLabelNode?

    /// Hermes health bar components
    private var hermesHealthBar: SKShapeNode?
    private var hermesHealthFill: SKShapeNode?
    private var hermesNameLabel: SKLabelNode?

    /// Cached health values (to avoid unnecessary updates)
    private var cachedNathanielHP: Int = -1
    private var cachedNathanielMaxHP: Int = -1
    private var cachedHermesHP: Int = -1
    private var cachedHermesMaxHP: Int = -1

    /// Currently selected character name (for highlight)
    private var selectedCharacterName: String = "Nathaniel"

    /// Player health bar constants
    private let playerHealthBarWidth: CGFloat = 90
    private let playerHealthBarHeight: CGFloat = 8

    // MARK: - Initialization

    init(size: CGSize, safeAreaInsets: HUDSafeAreaInsets = .zero) {
        viewportSize = size
        safeInsets = safeAreaInsets

        // Create containers
        topLeftContainer = SKNode()
        bottomContainer = SKNode()

        // Lives label
        livesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        livesLabel.fontSize = 16
        livesLabel.fontColor = .white
        livesLabel.horizontalAlignmentMode = .left
        livesLabel.verticalAlignmentMode = .top
        livesLabel.text = "LIVES"

        // Score label
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 16
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.text = "SCORE"

        scoreValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreValueLabel.fontSize = 24
        scoreValueLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        scoreValueLabel.horizontalAlignmentMode = .left
        scoreValueLabel.verticalAlignmentMode = .top
        scoreValueLabel.text = "0"

        // Resources label
        resourcesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        resourcesLabel.fontSize = 16
        resourcesLabel.fontColor = .white
        resourcesLabel.horizontalAlignmentMode = .left
        resourcesLabel.verticalAlignmentMode = .top
        resourcesLabel.text = "RESOURCES"

        resourcesValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        resourcesValueLabel.fontSize = 24
        resourcesValueLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        resourcesValueLabel.horizontalAlignmentMode = .left
        resourcesValueLabel.verticalAlignmentMode = .top
        resourcesValueLabel.text = "30"

        // Selected character
        selectedLabel = SKLabelNode(fontNamed: "Helvetica")
        selectedLabel.fontSize = 14
        selectedLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        selectedLabel.horizontalAlignmentMode = .center
        selectedLabel.verticalAlignmentMode = .bottom
        selectedLabel.text = "SELECTED"

        selectedCharacterLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        selectedCharacterLabel.fontSize = 18
        selectedCharacterLabel.fontColor = .white
        selectedCharacterLabel.horizontalAlignmentMode = .center
        selectedCharacterLabel.verticalAlignmentMode = .bottom
        selectedCharacterLabel.text = "NATHANIEL"

        // Timer
        timerLabel = SKLabelNode(fontNamed: "Menlo")
        timerLabel.fontSize = 14
        timerLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .top
        timerLabel.text = "00:00"

        super.init()

        setupLayout()
        zPosition = 500
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupLayout() {
        // Use percentage-based positioning that works regardless of scene size
        // The viewportSize represents the visible area in scene coordinates
        // Safe insets are already converted to scene coordinates
        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2

        // Base inset plus safe area
        let insetLeft = padding + safeInsets.left
        let insetRight = padding + safeInsets.right
        let insetTop = padding + safeInsets.top
        let insetBottom = padding + safeInsets.bottom

        // Top-left container position (LIVES and SCORE)
        topLeftContainer.position = CGPoint(
            x: -halfWidth + insetLeft,
            y: halfHeight - insetTop
        )
        addChild(topLeftContainer)

        // Add background panel for top-left (expanded to include resources)
        let topLeftBg = createBackgroundPanel(width: 130, height: 165)
        topLeftBg.position = CGPoint(x: 55, y: -72)
        topLeftContainer.addChild(topLeftBg)

        // Lives display
        livesLabel.position = CGPoint(x: 0, y: 0)
        livesLabel.zPosition = 1
        topLeftContainer.addChild(livesLabel)

        // Create initial lives icons (heart shapes or circles)
        updateLivesDisplay(lives: 3)

        // Score display (below lives)
        scoreLabel.position = CGPoint(x: 0, y: -50)
        scoreLabel.zPosition = 1
        topLeftContainer.addChild(scoreLabel)

        scoreValueLabel.position = CGPoint(x: 0, y: -70)
        scoreValueLabel.zPosition = 1
        topLeftContainer.addChild(scoreValueLabel)

        // Resources display (below score in top-left panel)
        resourcesLabel.position = CGPoint(x: 0, y: -100)
        resourcesLabel.zPosition = 1
        topLeftContainer.addChild(resourcesLabel)

        resourcesValueLabel.position = CGPoint(x: 0, y: -120)
        resourcesValueLabel.zPosition = 1
        topLeftContainer.addChild(resourcesValueLabel)

        // Timer (top center)
        timerLabel.position = CGPoint(x: 0, y: halfHeight - insetTop)
        addChild(timerLabel)

        // Add background for timer
        let timerBg = createBackgroundPanel(width: 80, height: 30)
        timerBg.position = CGPoint(x: 0, y: halfHeight - insetTop - 5)
        addChild(timerBg)
        timerLabel.zPosition = 1

        // Bottom container (selected character)
        bottomContainer.position = CGPoint(
            x: 0,
            y: -halfHeight + insetBottom + 30
        )
        addChild(bottomContainer)

        // Add background for bottom
        let bottomBg = createBackgroundPanel(width: 160, height: 50)
        bottomBg.position = CGPoint(x: 0, y: 10)
        bottomContainer.addChild(bottomBg)

        selectedLabel.position = CGPoint(x: 0, y: 20)
        selectedLabel.zPosition = 1
        bottomContainer.addChild(selectedLabel)

        selectedCharacterLabel.position = CGPoint(x: 0, y: 0)
        selectedCharacterLabel.zPosition = 1
        bottomContainer.addChild(selectedCharacterLabel)

        // Character toggle button (always visible, to the right of selected panel)
        setupCharacterToggleButton()

        // Pause button (always visible, top-right corner)
        setupPauseButton()

        // Player health display (bottom-left)
        setupPlayerHealthDisplay()
    }

    /// Setup the character toggle button
    private func setupCharacterToggleButton() {
        let halfHeight = viewportSize.height / 2
        let insetBottom = padding + safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = toggleButtonName
        button.zPosition = 600

        // Position to the right of the bottom "SELECTED" panel
        button.position = CGPoint(
            x: 120, // Offset from center (selected panel is at x=0)
            y: -halfHeight + insetBottom + 40
        )

        // Button background - circular for icon-style button
        let buttonBg = SKShapeNode(circleOfRadius: 25)
        buttonBg.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = toggleButtonName
        button.addChild(buttonBg)

        // Arrow icon using two arrow characters
        let arrowLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        arrowLabel.fontSize = 22
        arrowLabel.fontColor = .white
        arrowLabel.text = "⇄"
        arrowLabel.verticalAlignmentMode = .center
        arrowLabel.horizontalAlignmentMode = .center
        arrowLabel.name = toggleButtonName
        button.addChild(arrowLabel)

        addChild(button)
        characterToggleButton = button
    }

    /// Setup the Hermes follow mode toggle button
    private func setupFollowModeButton() {
        let halfHeight = viewportSize.height / 2
        let insetBottom = padding + safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = followButtonName
        button.zPosition = 600

        // Position to the left of the character toggle button
        button.position = CGPoint(
            x: 60, // Left of the character toggle at x=120
            y: -halfHeight + insetBottom + 40
        )

        // Button background - circular for icon-style button
        let buttonBg = SKShapeNode(circleOfRadius: 22)
        buttonBg.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = followButtonName
        button.addChild(buttonBg)

        // Icon - chain link for following, target for independent
        let icon = SKLabelNode(fontNamed: "Helvetica-Bold")
        icon.fontSize = 18
        icon.fontColor = .white
        icon.text = "🎯" // Default: independent (target)
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.name = followButtonName
        button.addChild(icon)
        followModeIcon = icon

        // Start hidden (shown when Nathaniel is selected)
        button.isHidden = true

        addChild(button)
        followModeButton = button
    }

    /// Setup the pause button (always visible)
    private func setupPauseButton() {
        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2
        let insetRight = padding + safeInsets.right
        let insetTop = padding + safeInsets.top

        // Create button container
        let button = SKNode()
        button.name = pauseButtonName
        button.zPosition = 600

        // Position in top-right corner, to the right of resources panel
        button.position = CGPoint(
            x: halfWidth - insetRight - 25, // Inset from right edge
            y: halfHeight - insetTop - 25 // Inset from top edge
        )

        // Button background - circular
        let buttonBg = SKShapeNode(circleOfRadius: 22)
        buttonBg.fillColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = pauseButtonName
        button.addChild(buttonBg)

        // Pause icon (two vertical bars using unicode)
        let pauseIcon = SKLabelNode(fontNamed: "Helvetica-Bold")
        pauseIcon.fontSize = 20
        pauseIcon.fontColor = .white
        pauseIcon.text = "⏸"
        pauseIcon.verticalAlignmentMode = .center
        pauseIcon.horizontalAlignmentMode = .center
        pauseIcon.name = pauseButtonName
        button.addChild(pauseIcon)

        addChild(button)
        pauseButton = button
    }

    /// Show the follow mode button (when Nathaniel is selected)
    func showFollowModeButton(isFollowing: Bool) {
        isHermesFollowing = isFollowing
        updateFollowModeButtonAppearance()

        guard let button = followModeButton else {
            setupFollowModeButton()
            followModeButton?.isHidden = false
            updateFollowModeButtonAppearance()
            return
        }

        if button.isHidden {
            button.isHidden = false
            // Animate in
            button.alpha = 0
            button.setScale(0.8)
            let fadeIn = SKAction.fadeIn(withDuration: 0.15)
            let scaleIn = SKAction.scale(to: 1.0, duration: 0.15)
            button.run(SKAction.group([fadeIn, scaleIn]))
        }
    }

    /// Hide the follow mode button
    func hideFollowModeButton() {
        guard let button = followModeButton, !button.isHidden else { return }

        // Animate out
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let scaleOut = SKAction.scale(to: 0.8, duration: 0.15)
        let hide = SKAction.run { button.isHidden = true }
        button.run(SKAction.sequence([SKAction.group([fadeOut, scaleOut]), hide]))
    }

    /// Update follow mode button to reflect current state
    func updateFollowMode(isFollowing: Bool) {
        isHermesFollowing = isFollowing
        updateFollowModeButtonAppearance()
    }

    /// Update the follow mode button appearance based on current state
    private func updateFollowModeButtonAppearance() {
        guard let button = followModeButton,
              let bg = button.children.first as? SKShapeNode else { return }

        if isHermesFollowing {
            // Following mode - chain link icon, green color
            followModeIcon?.text = "🔗"
            bg.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 0.9)
        } else {
            // Independent mode - target icon, blue color
            followModeIcon?.text = "🎯"
            bg.fillColor = SKColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.9)
        }
    }

    /// Create a semi-transparent background panel
    private func createBackgroundPanel(width: CGFloat, height: CGFloat) -> SKShapeNode {
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        panel.fillColor = SKColor.black.withAlphaComponent(0.5)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.3)
        panel.lineWidth = 1
        panel.zPosition = 0
        return panel
    }

    // MARK: - Player Health Display Setup

    /// Setup the player health display panel
    private func setupPlayerHealthDisplay() {
        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2
        let insetLeft = padding + safeInsets.left
        let insetBottom = padding + safeInsets.bottom

        // Create container for player health
        let container = SKNode()
        container.name = "playerHealthContainer"
        container.zPosition = 500

        // Position in bottom-left, above the build button area
        container.position = CGPoint(
            x: -halfWidth + insetLeft + 75,
            y: -halfHeight + insetBottom + 95
        )

        // Background panel
        let panelBg = createBackgroundPanel(width: 150, height: 65)
        panelBg.position = CGPoint(x: 0, y: 0)
        container.addChild(panelBg)

        // Nathaniel row (top)
        let nathanielY: CGFloat = 15

        let nathanielLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        nathanielLabel.fontSize = 11
        nathanielLabel.fontColor = .white
        nathanielLabel.horizontalAlignmentMode = .left
        nathanielLabel.verticalAlignmentMode = .center
        nathanielLabel.text = "NATHANIEL"
        nathanielLabel.position = CGPoint(x: -65, y: nathanielY)
        nathanielLabel.zPosition = 1
        container.addChild(nathanielLabel)
        nathanielNameLabel = nathanielLabel

        // Nathaniel health bar background (red)
        let nBarBg = SKShapeNode(
            rect: CGRect(
                x: 0,
                y: -playerHealthBarHeight / 2,
                width: playerHealthBarWidth,
                height: playerHealthBarHeight
            ),
            cornerRadius: 3
        )
        nBarBg.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 0.9)
        nBarBg.strokeColor = SKColor.white.withAlphaComponent(0.6)
        nBarBg.lineWidth = 1
        nBarBg.position = CGPoint(x: -15, y: nathanielY)
        nBarBg.zPosition = 1
        container.addChild(nBarBg)
        nathanielHealthBar = nBarBg

        // Nathaniel health bar fill (green)
        let nBarFill = SKShapeNode(
            rect: CGRect(
                x: 0,
                y: -playerHealthBarHeight / 2,
                width: playerHealthBarWidth,
                height: playerHealthBarHeight
            ),
            cornerRadius: 3
        )
        nBarFill.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        nBarFill.strokeColor = .clear
        nBarFill.lineWidth = 0
        nBarFill.position = CGPoint(x: -15, y: nathanielY)
        nBarFill.zPosition = 2
        container.addChild(nBarFill)
        nathanielHealthFill = nBarFill

        // Hermes row (bottom)
        let hermesY: CGFloat = -15

        let hermesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        hermesLabel.fontSize = 11
        hermesLabel.fontColor = SKColor(white: 0.85, alpha: 1.0)
        hermesLabel.horizontalAlignmentMode = .left
        hermesLabel.verticalAlignmentMode = .center
        hermesLabel.text = "HERMES"
        hermesLabel.position = CGPoint(x: -65, y: hermesY)
        hermesLabel.zPosition = 1
        container.addChild(hermesLabel)
        hermesNameLabel = hermesLabel

        // Hermes health bar background (red)
        let hBarBg = SKShapeNode(
            rect: CGRect(
                x: 0,
                y: -playerHealthBarHeight / 2,
                width: playerHealthBarWidth,
                height: playerHealthBarHeight
            ),
            cornerRadius: 3
        )
        hBarBg.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 0.9)
        hBarBg.strokeColor = SKColor.white.withAlphaComponent(0.6)
        hBarBg.lineWidth = 1
        hBarBg.position = CGPoint(x: -15, y: hermesY)
        hBarBg.zPosition = 1
        container.addChild(hBarBg)
        hermesHealthBar = hBarBg

        // Hermes health bar fill (cyan)
        let hBarFill = SKShapeNode(
            rect: CGRect(
                x: 0,
                y: -playerHealthBarHeight / 2,
                width: playerHealthBarWidth,
                height: playerHealthBarHeight
            ),
            cornerRadius: 3
        )
        hBarFill.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.85, alpha: 1.0)
        hBarFill.strokeColor = .clear
        hBarFill.lineWidth = 0
        hBarFill.position = CGPoint(x: -15, y: hermesY)
        hBarFill.zPosition = 2
        container.addChild(hBarFill)
        hermesHealthFill = hBarFill

        addChild(container)
        playerHealthContainer = container
    }

    /// Get color for health bar based on health percentage
    private func healthBarColor(percent: CGFloat, baseColor: SKColor) -> SKColor {
        if percent > 0.6 {
            baseColor
        } else if percent > 0.3 {
            // Yellow warning
            SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            // Red critical
            SKColor(red: 0.9, green: 0.25, blue: 0.2, alpha: 1.0)
        }
    }

    // MARK: - Updates

    /// Update lives display
    func updateLivesDisplay(lives: Int) {
        // Remove existing icons
        for icon in livesIcons {
            icon.removeFromParent()
        }
        livesIcons.removeAll()

        // Create new icons
        let iconSize: CGFloat = 20
        for i in 0 ..< lives {
            let icon = createHeartIcon(size: iconSize)
            icon.position = CGPoint(x: CGFloat(i) * (iconSize + 4), y: -25)
            topLeftContainer.addChild(icon)
            livesIcons.append(icon)
        }
    }

    /// Create a heart-shaped icon
    private func createHeartIcon(size: CGFloat) -> SKSpriteNode {
        // Create a simple circle for now (can be replaced with heart sprite)
        let node = SKShapeNode(circleOfRadius: size / 2)
        node.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        node.strokeColor = .white
        node.lineWidth = 1

        // Convert to texture for better performance
        let texture = SKView().texture(from: node)
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
        return sprite
    }

    /// Update score display
    func updateScore(_ score: Int) {
        scoreValueLabel.text = String(format: "%d", score)

        // Brief scale animation on score change
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scoreValueLabel.run(SKAction.sequence([scaleUp, scaleDown]))
    }

    /// Update resources display
    func updateResources(_ resources: Int) {
        resourcesValueLabel.text = String(format: "%d", resources)

        // Brief color flash on change
        let originalColor = resourcesValueLabel.fontColor
        resourcesValueLabel.fontColor = .white
        let restore = SKAction.run { [weak self] in
            self?.resourcesValueLabel.fontColor = originalColor
        }
        resourcesValueLabel.run(SKAction.sequence([SKAction.wait(forDuration: 0.1), restore]))
    }

    /// Update selected character display
    func updateSelectedCharacter(name: String, health: Int, maxHealth: Int) {
        selectedCharacterLabel.text = name.uppercased()
        selectedCharacterName = name

        // Color based on health percentage
        let healthPercent = CGFloat(health) / CGFloat(maxHealth)
        if healthPercent > 0.6 {
            selectedCharacterLabel.fontColor = .white
        } else if healthPercent > 0.3 {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }

        // Update name label highlights in player health display
        updatePlayerHealthHighlight()
    }

    /// Update player health bars
    /// - Parameters:
    ///   - nathanielHP: Current Nathaniel HP
    ///   - nathanielMaxHP: Max Nathaniel HP
    ///   - hermesHP: Current Hermes HP
    ///   - hermesMaxHP: Max Hermes HP
    func updatePlayerHealth(nathanielHP: Int, nathanielMaxHP: Int, hermesHP: Int, hermesMaxHP: Int) {
        // Update Nathaniel health bar if changed
        if nathanielHP != cachedNathanielHP || nathanielMaxHP != cachedNathanielMaxHP {
            cachedNathanielHP = nathanielHP
            cachedNathanielMaxHP = nathanielMaxHP
            updateHealthBarFill(
                fillNode: nathanielHealthFill,
                currentHP: nathanielHP,
                maxHP: nathanielMaxHP,
                baseColor: SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            )
        }

        // Update Hermes health bar if changed
        if hermesHP != cachedHermesHP || hermesMaxHP != cachedHermesMaxHP {
            cachedHermesHP = hermesHP
            cachedHermesMaxHP = hermesMaxHP
            updateHealthBarFill(
                fillNode: hermesHealthFill,
                currentHP: hermesHP,
                maxHP: hermesMaxHP,
                baseColor: SKColor(red: 0.2, green: 0.7, blue: 0.85, alpha: 1.0)
            )
        }
    }

    /// Update a single health bar fill
    private func updateHealthBarFill(fillNode: SKShapeNode?, currentHP: Int, maxHP: Int, baseColor: SKColor) {
        guard let fill = fillNode, maxHP > 0 else { return }

        let percent = CGFloat(currentHP) / CGFloat(maxHP)
        let fillWidth = playerHealthBarWidth * percent

        // Update fill width with rounded rect
        let fillRect = CGRect(
            x: 0,
            y: -playerHealthBarHeight / 2,
            width: max(fillWidth, 0),
            height: playerHealthBarHeight
        )
        if fillWidth > 6 {
            fill.path = CGPath(roundedRect: fillRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        } else {
            fill.path = CGPath(rect: fillRect, transform: nil)
        }

        // Update color based on health percentage
        fill.fillColor = healthBarColor(percent: percent, baseColor: baseColor)
    }

    /// Update highlight on selected character in player health panel
    private func updatePlayerHealthHighlight() {
        let isNathanielSelected = selectedCharacterName.lowercased().contains("nathaniel")

        // Highlight selected character's name
        nathanielNameLabel?.fontColor = isNathanielSelected ? .white : SKColor(white: 0.7, alpha: 1.0)
        hermesNameLabel?.fontColor = isNathanielSelected ? SKColor(white: 0.7, alpha: 1.0) : .white

        // Subtle border highlight on selected bar
        nathanielHealthBar?.strokeColor = isNathanielSelected
            ? SKColor.white.withAlphaComponent(0.9)
            : SKColor.white.withAlphaComponent(0.4)
        hermesHealthBar?.strokeColor = isNathanielSelected
            ? SKColor.white.withAlphaComponent(0.4)
            : SKColor.white.withAlphaComponent(0.9)
    }

    /// Flash player health bar when taking damage
    func flashPlayerHealth(isNathaniel: Bool) {
        let fillNode = isNathaniel ? nathanielHealthFill : hermesHealthFill
        guard let fill = fillNode else { return }

        // Flash white then restore
        let originalColor = fill.fillColor
        let flashWhite = SKAction.run { fill.fillColor = .white }
        let wait = SKAction.wait(forDuration: 0.08)
        let restore = SKAction.run { fill.fillColor = originalColor }
        fill.run(SKAction.sequence([flashWhite, wait, restore]))
    }

    /// Update timer display
    func updateTimer(elapsedTime: TimeInterval) {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    /// Full update from level manager state
    func update(lives: Int, score: Int, resources: Int, elapsedTime: TimeInterval) {
        // Only update lives if changed (to avoid recreating icons every frame)
        if livesIcons.count != lives {
            updateLivesDisplay(lives: lives)
        }

        // Update score only if changed (compare integers, not strings)
        if score != cachedScore {
            cachedScore = score
            updateScore(score)
        }

        // Update resources only if changed
        if resources != cachedResources {
            cachedResources = resources
            updateResources(resources)
        }

        updateTimer(elapsedTime: elapsedTime)
    }

    // MARK: - Animations

    /// Flash the lives display when a life is lost
    func flashLifeLost() {
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.15)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let flash = SKAction.sequence([fadeOut, fadeIn])
        topLeftContainer.run(SKAction.repeat(flash, count: 3))
    }

    /// Highlight score increase
    func highlightScoreIncrease(points: Int) {
        // Create floating "+points" text
        let floater = SKLabelNode(fontNamed: "Helvetica-Bold")
        floater.fontSize = 18
        floater.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        floater.text = "+\(points)"
        floater.position = CGPoint(x: scoreValueLabel.position.x + 60, y: scoreValueLabel.position.y - 10)
        topLeftContainer.addChild(floater)

        // Animate up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()
        floater.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }

    /// Highlight resource collection
    func highlightResourceCollected(amount: Int) {
        // Create floating "+amount" text
        let floater = SKLabelNode(fontNamed: "Helvetica-Bold")
        floater.fontSize = 18
        floater.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        floater.text = "+\(amount)"
        floater.position = CGPoint(x: resourcesValueLabel.position.x + 60, y: resourcesValueLabel.position.y - 10)
        floater.zPosition = 1
        topLeftContainer.addChild(floater)

        // Animate up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()
        floater.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }

    // MARK: - Release Hermes Button

    /// Label for release button (for updating text)
    private weak var releaseButtonLabel: SKLabelNode?
    private weak var releaseButtonRecoupLabel: SKLabelNode?

    /// Show the Release Hermes button with optional recoup preview
    /// - Parameter recoupAmount: Amount of resources that will be recovered (0 = no recoup)
    func showReleaseHermesButton(recoupAmount: Int = 0) {
        guard releaseHermesButton == nil else {
            releaseHermesButton?.isHidden = false
            updateReleaseButtonRecoup(recoupAmount)
            return
        }

        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2
        let insetRight = padding + safeInsets.right
        let insetBottom = padding + safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = releaseButtonName
        button.zPosition = 600

        // Position in bottom-right corner
        button.position = CGPoint(
            x: halfWidth - insetRight - 70,
            y: -halfHeight + insetBottom + 35
        )

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 140, height: 50), cornerRadius: 8)
        buttonBg.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = releaseButtonName
        button.addChild(buttonBg)

        // Button text
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.text = "RELEASE HERMES"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 6)
        label.name = releaseButtonName
        button.addChild(label)
        releaseButtonLabel = label

        // Recoup preview text (below main label)
        let recoupLabel = SKLabelNode(fontNamed: "Helvetica")
        recoupLabel.fontSize = 11
        recoupLabel.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0) // Light green
        recoupLabel.text = recoupAmount > 0 ? "+\(recoupAmount) resources" : ""
        recoupLabel.verticalAlignmentMode = .center
        recoupLabel.horizontalAlignmentMode = .center
        recoupLabel.position = CGPoint(x: 0, y: -10)
        recoupLabel.name = releaseButtonName
        button.addChild(recoupLabel)
        releaseButtonRecoupLabel = recoupLabel

        // Add subtle pulse animation
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        button.run(SKAction.repeatForever(pulse))

        addChild(button)
        releaseHermesButton = button

        // Animate in
        button.alpha = 0
        button.setScale(0.8)
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleIn = SKAction.scale(to: 1.0, duration: 0.2)
        button.run(SKAction.group([fadeIn, scaleIn]))
    }

    /// Hide the Release Hermes button
    func hideReleaseHermesButton() {
        guard let button = releaseHermesButton else { return }

        // Animate out
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleOut = SKAction.scale(to: 0.8, duration: 0.2)
        let remove = SKAction.run { [weak self] in
            self?.releaseHermesButton?.removeFromParent()
            self?.releaseHermesButton = nil
        }
        button.run(SKAction.sequence([SKAction.group([fadeOut, scaleOut]), remove]))
    }

    /// Update the recoup preview amount on the release button
    /// - Parameter amount: New recoup amount (0 = hide recoup text)
    func updateReleaseButtonRecoup(_ amount: Int) {
        if amount > 0 {
            releaseButtonRecoupLabel?.text = "+\(amount) resources"
        } else {
            releaseButtonRecoupLabel?.text = ""
        }
    }

    // MARK: - Build Button

    /// Show the Build button (when Hermes is selected)
    func showBuildButton() {
        isHermesSelected = true
        guard buildButton == nil else {
            buildButton?.isHidden = false
            return
        }

        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2
        let insetLeft = padding + safeInsets.left
        let insetBottom = padding + safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = buildButtonName
        button.zPosition = 600

        // Position in bottom-left corner
        button.position = CGPoint(
            x: -halfWidth + insetLeft + 50,
            y: -halfHeight + insetBottom + 35
        )

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 50), cornerRadius: 8)
        buttonBg.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = buildButtonName
        button.addChild(buttonBg)

        // Button text
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 16
        label.fontColor = .white
        label.text = "BUILD"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = buildButtonName
        button.addChild(label)

        addChild(button)
        buildButton = button

        // Animate in
        button.alpha = 0
        button.setScale(0.8)
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleIn = SKAction.scale(to: 1.0, duration: 0.2)
        button.run(SKAction.group([fadeIn, scaleIn]))
    }

    /// Hide the Build button
    func hideBuildButton() {
        isHermesSelected = false
        guard let button = buildButton else { return }

        // Animate out
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleOut = SKAction.scale(to: 0.8, duration: 0.2)
        let remove = SKAction.run { [weak self] in
            self?.buildButton?.removeFromParent()
            self?.buildButton = nil
        }
        button.run(SKAction.sequence([SKAction.group([fadeOut, scaleOut]), remove]))
    }

    // MARK: - Tower Count Display

    /// Update the tower count display
    func updateTowerCount(_ count: Int) {
        if count > 0 {
            showTowerCount(count)
        } else {
            hideTowerCount()
        }
    }

    /// Show tower count
    private func showTowerCount(_ count: Int) {
        if towerCountLabel == nil {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.fontSize = 14
            label.fontColor = SKColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1.0)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 1

            // Position below resources in top-left panel
            label.position = CGPoint(x: 0, y: -145)
            topLeftContainer.addChild(label)
            towerCountLabel = label
        }

        towerCountLabel?.text = "TOWERS: \(count)"
        towerCountLabel?.isHidden = false
    }

    /// Hide tower count
    private func hideTowerCount() {
        towerCountLabel?.isHidden = true
    }

    /// Handle touch on HUD - returns true if touch was handled
    func handleTouch(at point: CGPoint) -> Bool {
        // Check if touch is on pause button
        if let button = pauseButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint)
            {
                // Trigger callback
                onPauseTapped?()

                // Visual feedback - scale pop
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                button.run(SKAction.sequence([scaleUp, scaleDown]))

                return true
            }
        }

        // Check if touch is on character toggle button
        if let button = characterToggleButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint)
            {
                // Trigger callback
                onCharacterToggle?()

                // Visual feedback - scale pop
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                button.run(SKAction.sequence([scaleUp, scaleDown]))

                return true
            }
        }

        // Check if touch is on follow mode button
        if let button = followModeButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint)
            {
                // Trigger callback
                onFollowModeToggle?()

                // Visual feedback - scale pop
                let scaleUp = SKAction.scale(to: 1.15, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                button.run(SKAction.sequence([scaleUp, scaleDown]))

                return true
            }
        }

        // Check if touch is on build button
        if let button = buildButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint)
            {
                // Trigger callback
                onBuildTapped?()

                // Visual feedback
                let flash = SKAction.sequence([
                    SKAction.colorize(with: .white, colorBlendFactor: 0.5, duration: 0.1),
                    SKAction.colorize(withColorBlendFactor: 0, duration: 0.1),
                ])
                bg.run(flash)

                return true
            }
        }

        // Check if touch is on release button
        if let button = releaseHermesButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint)
            {
                // Trigger callback
                onReleaseHermes?()

                // Visual feedback
                let flash = SKAction.sequence([
                    SKAction.colorize(with: .white, colorBlendFactor: 0.5, duration: 0.1),
                    SKAction.colorize(withColorBlendFactor: 0, duration: 0.1),
                ])
                bg.run(flash)

                return true
            }
        }
        return false
    }
}
