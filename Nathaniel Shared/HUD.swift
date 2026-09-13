//
//  HUD.swift
//  Nathaniel Shared
//
//  Shows player status and gameplay controls.
//

import SpriteKit

// MARK: - Safe Area Insets

/// Cross-platform struct for safe area insets (in scene coordinates)
struct HUDSafeAreaInsets {
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat

    static let zero = HUDSafeAreaInsets(top: 0, bottom: 0, left: 0, right: 0)
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

    /// Hermes follow/stop control, available with either character selected.
    private var followModeButton: SKNode?
    private let followButtonName = "followModeButton"
    private var followModeLabel: SKLabelNode?

    /// Callback when follow mode button is tapped
    var onFollowModeToggle: (() -> Void)?

    /// Whether Hermes is currently in follow mode
    private var isHermesFollowing: Bool = false

    /// Pause button (always visible during gameplay)
    private var pauseButton: SKNode?
    private let pauseButtonName = "pauseButton"

    /// Callback when pause button is tapped
    var onPauseTapped: (() -> Void)?

    /// Padding from screen edges
    private let padding: CGFloat = 16

    // MARK: - Player Health Display

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
        self.viewportSize = size
        self.safeInsets = safeAreaInsets

        // Create containers
        self.topLeftContainer = SKNode()
        self.bottomContainer = SKNode()

        // Lives label
        self.livesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.livesLabel.fontSize = 16
        self.livesLabel.fontColor = .white
        self.livesLabel.horizontalAlignmentMode = .left
        self.livesLabel.verticalAlignmentMode = .top
        self.livesLabel.text = "LIVES"

        // Score label
        self.scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.scoreLabel.fontSize = 16
        self.scoreLabel.fontColor = .white
        self.scoreLabel.horizontalAlignmentMode = .left
        self.scoreLabel.verticalAlignmentMode = .top
        self.scoreLabel.text = "SCORE"

        self.scoreValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.scoreValueLabel.fontSize = 24
        self.scoreValueLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        self.scoreValueLabel.horizontalAlignmentMode = .left
        self.scoreValueLabel.verticalAlignmentMode = .top
        self.scoreValueLabel.text = "0"

        // Resources label
        self.resourcesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.resourcesLabel.fontSize = 16
        self.resourcesLabel.fontColor = .white
        self.resourcesLabel.horizontalAlignmentMode = .left
        self.resourcesLabel.verticalAlignmentMode = .top
        self.resourcesLabel.text = "RESOURCES"

        self.resourcesValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.resourcesValueLabel.fontSize = 24
        self.resourcesValueLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        self.resourcesValueLabel.horizontalAlignmentMode = .left
        self.resourcesValueLabel.verticalAlignmentMode = .top
        self.resourcesValueLabel.text = "30"

        // Selected character
        self.selectedLabel = SKLabelNode(fontNamed: "Helvetica")
        self.selectedLabel.fontSize = 14
        self.selectedLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        self.selectedLabel.horizontalAlignmentMode = .center
        self.selectedLabel.verticalAlignmentMode = .bottom
        self.selectedLabel.text = "SELECTED"

        self.selectedCharacterLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.selectedCharacterLabel.fontSize = 18
        self.selectedCharacterLabel.fontColor = .white
        self.selectedCharacterLabel.horizontalAlignmentMode = .center
        self.selectedCharacterLabel.verticalAlignmentMode = .bottom
        self.selectedCharacterLabel.text = "NATHANIEL"

        // Timer
        self.timerLabel = SKLabelNode(fontNamed: "Menlo")
        self.timerLabel.fontSize = 14
        self.timerLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        self.timerLabel.horizontalAlignmentMode = .center
        self.timerLabel.verticalAlignmentMode = .top
        self.timerLabel.text = "00:00"

        super.init()

        self.setupLayout()
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
        let halfWidth = self.viewportSize.width / 2
        let halfHeight = self.viewportSize.height / 2

        // Base inset plus safe area
        let insetLeft = self.padding + self.safeInsets.left
        let insetRight = self.padding + self.safeInsets.right
        let insetTop = self.padding + self.safeInsets.top
        let insetBottom = self.padding + self.safeInsets.bottom

        // Top-left container position (LIVES and SCORE)
        self.topLeftContainer.position = CGPoint(
            x: -halfWidth + insetLeft,
            y: halfHeight - insetTop
        )
        addChild(self.topLeftContainer)

        // Add background panel for top-left (expanded to include resources)
        let topLeftBg = self.createBackgroundPanel(width: 130, height: 165)
        topLeftBg.position = CGPoint(x: 55, y: -72)
        self.topLeftContainer.addChild(topLeftBg)

        // Lives display
        self.livesLabel.position = CGPoint(x: 0, y: 0)
        self.livesLabel.zPosition = 1
        self.topLeftContainer.addChild(self.livesLabel)

        // Create initial lives icons (heart shapes or circles)
        self.updateLivesDisplay(lives: 3)

        // Score display (below lives)
        self.scoreLabel.position = CGPoint(x: 0, y: -50)
        self.scoreLabel.zPosition = 1
        self.topLeftContainer.addChild(self.scoreLabel)

        self.scoreValueLabel.position = CGPoint(x: 0, y: -70)
        self.scoreValueLabel.zPosition = 1
        self.topLeftContainer.addChild(self.scoreValueLabel)

        // Resources display (below score in top-left panel)
        self.resourcesLabel.position = CGPoint(x: 0, y: -100)
        self.resourcesLabel.zPosition = 1
        self.topLeftContainer.addChild(self.resourcesLabel)

        self.resourcesValueLabel.position = CGPoint(x: 0, y: -120)
        self.resourcesValueLabel.zPosition = 1
        self.topLeftContainer.addChild(self.resourcesValueLabel)

        // Timer (top center)
        self.timerLabel.position = CGPoint(x: 0, y: halfHeight - insetTop)
        addChild(self.timerLabel)

        // Add background for timer
        let timerBg = self.createBackgroundPanel(width: 80, height: 30)
        timerBg.position = CGPoint(x: 0, y: halfHeight - insetTop - 5)
        addChild(timerBg)
        self.timerLabel.zPosition = 1

        // Bottom container (selected character)
        self.bottomContainer.position = CGPoint(
            x: 0,
            y: -halfHeight + insetBottom + 30
        )
        addChild(self.bottomContainer)

        // Add background for bottom
        let bottomBg = self.createBackgroundPanel(width: 160, height: 50)
        bottomBg.position = CGPoint(x: 0, y: 10)
        self.bottomContainer.addChild(bottomBg)

        self.selectedLabel.position = CGPoint(x: 0, y: 20)
        self.selectedLabel.zPosition = 1
        self.bottomContainer.addChild(self.selectedLabel)

        self.selectedCharacterLabel.position = CGPoint(x: 0, y: 0)
        self.selectedCharacterLabel.zPosition = 1
        self.bottomContainer.addChild(self.selectedCharacterLabel)

        // Character toggle button (always visible, to the right of selected panel)
        self.setupCharacterToggleButton()
        self.setupFollowModeButton()

        // Pause button (always visible, top-right corner)
        self.setupPauseButton()

        // Player health display (bottom-left)
        self.setupPlayerHealthDisplay()
    }

    /// Setup the character toggle button
    private func setupCharacterToggleButton() {
        let halfHeight = self.viewportSize.height / 2
        let insetBottom = self.padding + self.safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = self.toggleButtonName
        button.zPosition = 100

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
        buttonBg.name = self.toggleButtonName
        button.addChild(buttonBg)

        // Arrow icon using two arrow characters
        let arrowLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        arrowLabel.fontSize = 22
        arrowLabel.fontColor = .white
        arrowLabel.text = "⇄"
        arrowLabel.verticalAlignmentMode = .center
        arrowLabel.horizontalAlignmentMode = .center
        arrowLabel.name = self.toggleButtonName
        button.addChild(arrowLabel)

        addChild(button)
        self.characterToggleButton = button
    }

    /// Setup the Hermes follow mode toggle button
    private func setupFollowModeButton() {
        let halfHeight = self.viewportSize.height / 2
        let insetBottom = self.padding + self.safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = self.followButtonName
        button.zPosition = 100

        // Keep the follow control clear of the selected-character panel and toggle.
        button.position = CGPoint(
            x: 210,
            y: -halfHeight + insetBottom + 40
        )

        let buttonBg = SKShapeNode(rectOf: CGSize(width: 88, height: 44), cornerRadius: 8)
        buttonBg.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 0.9)
        buttonBg.strokeColor = .white
        buttonBg.lineWidth = 2
        buttonBg.name = self.followButtonName
        button.addChild(buttonBg)

        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.fontSize = 9
        title.text = "HERMES"
        title.position.y = 10
        title.verticalAlignmentMode = .center
        button.addChild(title)

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.text = "FOLLOW"
        label.position.y = -6
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = self.followButtonName
        button.addChild(label)
        self.followModeLabel = label

        addChild(button)
        self.followModeButton = button
    }

    /// Setup the pause button (always visible)
    private func setupPauseButton() {
        let halfWidth = self.viewportSize.width / 2
        let halfHeight = self.viewportSize.height / 2
        let insetRight = self.padding + self.safeInsets.right
        let insetTop = self.padding + self.safeInsets.top

        // Create button container
        let button = SKNode()
        button.name = self.pauseButtonName
        button.zPosition = 100

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
        buttonBg.name = self.pauseButtonName
        button.addChild(buttonBg)

        // Pause icon (two vertical bars using unicode)
        let pauseIcon = SKLabelNode(fontNamed: "Helvetica-Bold")
        pauseIcon.fontSize = 20
        pauseIcon.fontColor = .white
        pauseIcon.text = "⏸"
        pauseIcon.verticalAlignmentMode = .center
        pauseIcon.horizontalAlignmentMode = .center
        pauseIcon.name = self.pauseButtonName
        button.addChild(pauseIcon)

        addChild(button)
        self.pauseButton = button
    }

    /// Update follow mode button to reflect current state
    func updateFollowMode(isFollowing: Bool) {
        self.isHermesFollowing = isFollowing
        self.updateFollowModeButtonAppearance()
    }

    /// Update the follow mode button appearance based on current state
    private func updateFollowModeButtonAppearance() {
        guard let button = followModeButton,
              let bg = button.children.first as? SKShapeNode else { return }

        if self.isHermesFollowing {
            self.followModeLabel?.text = "STOP"
            bg.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 0.9)
        } else {
            self.followModeLabel?.text = "FOLLOW"
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
        let halfWidth = self.viewportSize.width / 2
        let halfHeight = self.viewportSize.height / 2
        let insetLeft = self.padding + self.safeInsets.left
        let insetBottom = self.padding + self.safeInsets.bottom
        let panelWidth: CGFloat = 190
        let labelX = -panelWidth / 2 + 10
        let barX = panelWidth / 2 - 10 - self.playerHealthBarWidth

        // Create container for player health
        let container = SKNode()
        container.name = "playerHealthContainer"

        // Position in bottom-left, above the build button area
        container.position = CGPoint(
            x: -halfWidth + insetLeft + panelWidth / 2,
            y: -halfHeight + insetBottom + 95
        )

        // Background panel
        let panelBg = self.createBackgroundPanel(width: panelWidth, height: 65)
        panelBg.position = CGPoint(x: 0, y: 0)
        container.addChild(panelBg)

        let healthBarFrame = CGRect(
            x: 0,
            y: -self.playerHealthBarHeight / 2,
            width: self.playerHealthBarWidth,
            height: self.playerHealthBarHeight
        )

        // Nathaniel row (top)
        let nathanielY: CGFloat = 15

        let nathanielLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        nathanielLabel.fontSize = 11
        nathanielLabel.fontColor = .white
        nathanielLabel.horizontalAlignmentMode = .left
        nathanielLabel.verticalAlignmentMode = .center
        nathanielLabel.text = "NATHANIEL"
        nathanielLabel.position = CGPoint(x: labelX, y: nathanielY)
        nathanielLabel.zPosition = 1
        container.addChild(nathanielLabel)
        self.nathanielNameLabel = nathanielLabel

        // Nathaniel health bar background (red)
        let nBarBg = SKShapeNode(rect: healthBarFrame, cornerRadius: 3)
        nBarBg.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 0.9)
        nBarBg.strokeColor = SKColor.white.withAlphaComponent(0.6)
        nBarBg.lineWidth = 1
        nBarBg.position = CGPoint(x: barX, y: nathanielY)
        nBarBg.zPosition = 1
        container.addChild(nBarBg)
        self.nathanielHealthBar = nBarBg

        // Nathaniel health bar fill (green)
        let nBarFill = SKShapeNode(rect: healthBarFrame, cornerRadius: 3)
        nBarFill.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        nBarFill.strokeColor = .clear
        nBarFill.lineWidth = 0
        nBarFill.position = CGPoint(x: barX, y: nathanielY)
        nBarFill.zPosition = 2
        container.addChild(nBarFill)
        self.nathanielHealthFill = nBarFill

        // Hermes row (bottom)
        let hermesY: CGFloat = -15

        let hermesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        hermesLabel.fontSize = 11
        hermesLabel.fontColor = SKColor(white: 0.85, alpha: 1.0)
        hermesLabel.horizontalAlignmentMode = .left
        hermesLabel.verticalAlignmentMode = .center
        hermesLabel.text = "HERMES"
        hermesLabel.position = CGPoint(x: labelX, y: hermesY)
        hermesLabel.zPosition = 1
        container.addChild(hermesLabel)
        self.hermesNameLabel = hermesLabel

        // Hermes health bar background (red)
        let hBarBg = SKShapeNode(rect: healthBarFrame, cornerRadius: 3)
        hBarBg.fillColor = SKColor(red: 0.5, green: 0.15, blue: 0.15, alpha: 0.9)
        hBarBg.strokeColor = SKColor.white.withAlphaComponent(0.6)
        hBarBg.lineWidth = 1
        hBarBg.position = CGPoint(x: barX, y: hermesY)
        hBarBg.zPosition = 1
        container.addChild(hBarBg)
        self.hermesHealthBar = hBarBg

        // Hermes health bar fill (cyan)
        let hBarFill = SKShapeNode(rect: healthBarFrame, cornerRadius: 3)
        hBarFill.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.85, alpha: 1.0)
        hBarFill.strokeColor = .clear
        hBarFill.lineWidth = 0
        hBarFill.position = CGPoint(x: barX, y: hermesY)
        hBarFill.zPosition = 2
        container.addChild(hBarFill)
        self.hermesHealthFill = hBarFill

        addChild(container)
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
        for icon in self.livesIcons {
            icon.removeFromParent()
        }
        self.livesIcons.removeAll()

        // Create new icons
        let iconSize: CGFloat = 20
        for i in 0 ..< lives {
            let icon = self.createHeartIcon(size: iconSize)
            icon.position = CGPoint(x: CGFloat(i) * (iconSize + 4), y: -25)
            self.topLeftContainer.addChild(icon)
            self.livesIcons.append(icon)
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
        return SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
    }

    /// Update score display
    func updateScore(_ score: Int) {
        self.scoreValueLabel.text = String(format: "%d", score)

        // Brief scale animation on score change
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        self.scoreValueLabel.run(SKAction.sequence([scaleUp, scaleDown]))
    }

    /// Update resources display
    func updateResources(_ resources: Int) {
        self.resourcesValueLabel.text = String(format: "%d", resources)

        // Brief color flash on change
        let originalColor = self.resourcesValueLabel.fontColor
        self.resourcesValueLabel.fontColor = .white
        let restore = SKAction.run { [weak self] in
            self?.resourcesValueLabel.fontColor = originalColor
        }
        self.resourcesValueLabel.run(SKAction.sequence([SKAction.wait(forDuration: 0.1), restore]))
    }

    /// Update selected character display
    func updateSelectedCharacter(name: String, health: Int, maxHealth: Int) {
        self.selectedCharacterLabel.text = name.uppercased()
        self.selectedCharacterName = name

        // Color based on health percentage
        let healthPercent = CGFloat(health) / CGFloat(maxHealth)
        if healthPercent > 0.6 {
            self.selectedCharacterLabel.fontColor = .white
        } else if healthPercent > 0.3 {
            self.selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            self.selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }

        // Update name label highlights in player health display
        self.updatePlayerHealthHighlight()
    }

    /// Update player health bars
    /// - Parameters:
    ///   - nathanielHP: Current Nathaniel HP
    ///   - nathanielMaxHP: Max Nathaniel HP
    ///   - hermesHP: Current Hermes HP
    ///   - hermesMaxHP: Max Hermes HP
    func updatePlayerHealth(nathanielHP: Int, nathanielMaxHP: Int, hermesHP: Int, hermesMaxHP: Int) {
        // Update Nathaniel health bar if changed
        if nathanielHP != self.cachedNathanielHP || nathanielMaxHP != self.cachedNathanielMaxHP {
            self.cachedNathanielHP = nathanielHP
            self.cachedNathanielMaxHP = nathanielMaxHP
            self.updateHealthBarFill(
                fillNode: self.nathanielHealthFill,
                currentHP: nathanielHP,
                maxHP: nathanielMaxHP,
                baseColor: SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            )
        }

        // Update Hermes health bar if changed
        if hermesHP != self.cachedHermesHP || hermesMaxHP != self.cachedHermesMaxHP {
            self.cachedHermesHP = hermesHP
            self.cachedHermesMaxHP = hermesMaxHP
            self.updateHealthBarFill(
                fillNode: self.hermesHealthFill,
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
        let fillWidth = self.playerHealthBarWidth * percent

        // Update fill width with rounded rect
        let fillRect = CGRect(
            x: 0,
            y: -self.playerHealthBarHeight / 2,
            width: max(fillWidth, 0),
            height: self.playerHealthBarHeight
        )
        if fillWidth > 6 {
            fill.path = CGPath(roundedRect: fillRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        } else {
            fill.path = CGPath(rect: fillRect, transform: nil)
        }

        // Update color based on health percentage
        fill.fillColor = self.healthBarColor(percent: percent, baseColor: baseColor)
    }

    /// Update highlight on selected character in player health panel
    private func updatePlayerHealthHighlight() {
        let isNathanielSelected = self.selectedCharacterName.lowercased().contains("nathaniel")

        // Highlight selected character's name
        self.nathanielNameLabel?.fontColor = isNathanielSelected ? .white : SKColor(white: 0.7, alpha: 1.0)
        self.hermesNameLabel?.fontColor = isNathanielSelected ? SKColor(white: 0.7, alpha: 1.0) : .white

        // Subtle border highlight on selected bar
        self.nathanielHealthBar?.strokeColor = isNathanielSelected
            ? SKColor.white.withAlphaComponent(0.9)
            : SKColor.white.withAlphaComponent(0.4)
        self.hermesHealthBar?.strokeColor = isNathanielSelected
            ? SKColor.white.withAlphaComponent(0.4)
            : SKColor.white.withAlphaComponent(0.9)
    }

    /// Update timer display
    func updateTimer(elapsedTime: TimeInterval) {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        self.timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    /// Full update from level manager state
    func update(lives: Int, score: Int, resources: Int, elapsedTime: TimeInterval) {
        // Only update lives if changed (to avoid recreating icons every frame)
        if self.livesIcons.count != lives {
            self.updateLivesDisplay(lives: lives)
        }

        // Update score only if changed (compare integers, not strings)
        if score != self.cachedScore {
            self.cachedScore = score
            self.updateScore(score)
        }

        // Update resources only if changed
        if resources != self.cachedResources {
            self.cachedResources = resources
            self.updateResources(resources)
        }

        self.updateTimer(elapsedTime: elapsedTime)
    }

    // MARK: - Animations

    /// Flash the lives display when a life is lost
    func flashLifeLost() {
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.15)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let flash = SKAction.sequence([fadeOut, fadeIn])
        self.topLeftContainer.run(SKAction.repeat(flash, count: 3))
    }

    /// Highlight resource collection
    func highlightResourceCollected(amount: Int) {
        // Create floating "+amount" text
        let floater = SKLabelNode(fontNamed: "Helvetica-Bold")
        floater.fontSize = 18
        floater.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        floater.text = "+\(amount)"
        floater.position = CGPoint(
            x: self.resourcesValueLabel.position.x + 60,
            y: self.resourcesValueLabel.position.y - 10
        )
        floater.zPosition = 1
        self.topLeftContainer.addChild(floater)

        // Animate up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()
        floater.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }

    // MARK: - Build Button

    /// Show the Build button (when Hermes is selected)
    func showBuildButton() {
        guard self.buildButton == nil else {
            self.buildButton?.removeAction(forKey: "hideBuildButton")
            self.buildButton?.isHidden = false
            self.buildButton?.alpha = 1
            self.buildButton?.setScale(1)
            return
        }

        let halfWidth = self.viewportSize.width / 2
        let halfHeight = self.viewportSize.height / 2
        let insetLeft = self.padding + self.safeInsets.left
        let insetBottom = self.padding + self.safeInsets.bottom

        // Create button container
        let button = SKNode()
        button.name = self.buildButtonName
        button.zPosition = 100

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
        buttonBg.name = self.buildButtonName
        button.addChild(buttonBg)

        // Button text
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 16
        label.fontColor = .white
        label.text = "BUILD"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = self.buildButtonName
        button.addChild(label)

        addChild(button)
        self.buildButton = button

        // Animate in
        button.alpha = 0
        button.setScale(0.8)
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleIn = SKAction.scale(to: 1.0, duration: 0.2)
        button.run(SKAction.group([fadeIn, scaleIn]))
    }

    /// Hide the Build button
    func hideBuildButton() {
        guard let button = buildButton else { return }

        // Animate out
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleOut = SKAction.scale(to: 0.8, duration: 0.2)
        let remove = SKAction.run { [weak self] in
            self?.buildButton?.removeFromParent()
            self?.buildButton = nil
        }
        button.run(SKAction.sequence([SKAction.group([fadeOut, scaleOut]), remove]), withKey: "hideBuildButton")
    }

    // MARK: - Tower Count Display

    /// Update the tower count display
    func updateTowerCount(_ count: Int) {
        if count > 0 {
            self.showTowerCount(count)
        } else {
            self.hideTowerCount()
        }
    }

    /// Show tower count
    private func showTowerCount(_ count: Int) {
        if self.towerCountLabel == nil {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.fontSize = 14
            label.fontColor = SKColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1.0)
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 1

            // Position below resources in top-left panel
            label.position = CGPoint(x: 0, y: -145)
            self.topLeftContainer.addChild(label)
            self.towerCountLabel = label
        }

        self.towerCountLabel?.text = "TOWERS: \(count)"
        self.towerCountLabel?.isHidden = false
    }

    /// Hide tower count
    private func hideTowerCount() {
        self.towerCountLabel?.isHidden = true
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
                self.onPauseTapped?()

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
                self.onCharacterToggle?()

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
                self.onFollowModeToggle?()

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
                self.onBuildTapped?()

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
