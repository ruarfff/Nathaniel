//
//  HUD.swift
//  Nathaniel Shared
//
//  Heads-up display for game information: lives, score, resources, and selected character.
//

import SpriteKit

// MARK: - HUD

/// Heads-up display overlay showing game status
class HUD: SKNode {

    // MARK: - Properties

    /// Size of the viewport
    private let viewportSize: CGSize

    /// Container for top-left info (lives, score)
    private let topLeftContainer: SKNode

    /// Container for top-right info (resources)
    private let topRightContainer: SKNode

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

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size

        // Create containers
        topLeftContainer = SKNode()
        topRightContainer = SKNode()
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
        resourcesLabel.horizontalAlignmentMode = .right
        resourcesLabel.verticalAlignmentMode = .top
        resourcesLabel.text = "RESOURCES"

        resourcesValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        resourcesValueLabel.fontSize = 24
        resourcesValueLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        resourcesValueLabel.horizontalAlignmentMode = .right
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupLayout() {
        // Use percentage-based positioning that works regardless of scene size
        // Scene size may be 800x480 (from SKS) or something else
        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2

        // Fixed inset values that work well for most sizes
        let insetX: CGFloat = 20
        let insetY: CGFloat = 20

        print("HUD: viewportSize = \(viewportSize), halfWidth = \(halfWidth), halfHeight = \(halfHeight)")

        // Top-left container position
        topLeftContainer.position = CGPoint(
            x: -halfWidth + insetX + padding,
            y: halfHeight - insetY - padding
        )
        addChild(topLeftContainer)

        // Add background panel for top-left
        let topLeftBg = createBackgroundPanel(width: 120, height: 100)
        topLeftBg.position = CGPoint(x: 50, y: -40)
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

        // Top-right container position
        topRightContainer.position = CGPoint(
            x: halfWidth - insetX - padding - 100,  // Extra offset for right-aligned text
            y: halfHeight - insetY - padding
        )
        addChild(topRightContainer)

        // Add background panel for top-right
        let topRightBg = createBackgroundPanel(width: 120, height: 60)
        topRightBg.position = CGPoint(x: 50, y: -20)
        topRightContainer.addChild(topRightBg)

        // Resources display
        resourcesLabel.position = CGPoint(x: 0, y: 0)
        resourcesLabel.zPosition = 1
        resourcesLabel.horizontalAlignmentMode = .left
        topRightContainer.addChild(resourcesLabel)

        resourcesValueLabel.position = CGPoint(x: 0, y: -20)
        resourcesValueLabel.zPosition = 1
        resourcesValueLabel.horizontalAlignmentMode = .left
        topRightContainer.addChild(resourcesValueLabel)

        // Timer (top center)
        timerLabel.position = CGPoint(x: 0, y: halfHeight - insetY - padding)
        addChild(timerLabel)

        // Add background for timer
        let timerBg = createBackgroundPanel(width: 80, height: 30)
        timerBg.position = CGPoint(x: 0, y: halfHeight - insetY - padding - 5)
        addChild(timerBg)
        timerLabel.zPosition = 1

        // Bottom container (selected character)
        bottomContainer.position = CGPoint(
            x: 0,
            y: -halfHeight + insetY + padding + 30
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
    }

    /// Setup the character toggle button
    private func setupCharacterToggleButton() {
        let halfHeight = viewportSize.height / 2
        let insetY: CGFloat = 20

        // Create button container
        let button = SKNode()
        button.name = toggleButtonName
        button.zPosition = 600

        // Position to the right of the bottom "SELECTED" panel
        button.position = CGPoint(
            x: 120,  // Offset from center (selected panel is at x=0)
            y: -halfHeight + insetY + padding + 40
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
        let insetY: CGFloat = 20

        // Create button container
        let button = SKNode()
        button.name = followButtonName
        button.zPosition = 600

        // Position to the left of the character toggle button
        button.position = CGPoint(
            x: 60,  // Left of the character toggle at x=120
            y: -halfHeight + insetY + padding + 40
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
        icon.text = "🎯"  // Default: independent (target)
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
        let insetX: CGFloat = 20
        let insetY: CGFloat = 20

        // Create button container
        let button = SKNode()
        button.name = pauseButtonName
        button.zPosition = 600

        // Position in top-right corner, to the right of resources panel
        button.position = CGPoint(
            x: halfWidth - insetX - 25,  // Inset from right edge
            y: halfHeight - insetY - 25  // Inset from top edge
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
        for i in 0..<lives {
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

        // Color based on health percentage
        let healthPercent = CGFloat(health) / CGFloat(maxHealth)
        if healthPercent > 0.6 {
            selectedCharacterLabel.fontColor = .white
        } else if healthPercent > 0.3 {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
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
        topRightContainer.addChild(floater)

        // Animate up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()
        floater.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }

    // MARK: - Release Hermes Button

    /// Show the Release Hermes button
    func showReleaseHermesButton() {
        guard releaseHermesButton == nil else {
            releaseHermesButton?.isHidden = false
            return
        }

        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2

        // Create button container
        let button = SKNode()
        button.name = releaseButtonName
        button.zPosition = 600

        // Position in bottom-right corner
        button.position = CGPoint(
            x: halfWidth - 90,
            y: -halfHeight + 60
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
        label.name = releaseButtonName
        button.addChild(label)

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

        // Create button container
        let button = SKNode()
        button.name = buildButtonName
        button.zPosition = 600

        // Position in bottom-left corner
        button.position = CGPoint(
            x: -halfWidth + 80,
            y: -halfHeight + 60
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

            // Position below resources
            label.position = CGPoint(x: 0, y: -45)
            topRightContainer.addChild(label)
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
               bg.contains(buttonPoint) {
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
               bg.contains(buttonPoint) {
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
               bg.contains(buttonPoint) {
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
               bg.contains(buttonPoint) {
                // Trigger callback
                onBuildTapped?()

                // Visual feedback
                let flash = SKAction.sequence([
                    SKAction.colorize(with: .white, colorBlendFactor: 0.5, duration: 0.1),
                    SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
                ])
                bg.run(flash)

                return true
            }
        }

        // Check if touch is on release button
        if let button = releaseHermesButton, !button.isHidden {
            let buttonPoint = convert(point, to: button)
            if let bg = button.children.first as? SKShapeNode,
               bg.contains(buttonPoint) {
                // Trigger callback
                onReleaseHermes?()

                // Visual feedback
                let flash = SKAction.sequence([
                    SKAction.colorize(with: .white, colorBlendFactor: 0.5, duration: 0.1),
                    SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
                ])
                bg.run(flash)

                return true
            }
        }
        return false
    }
}
